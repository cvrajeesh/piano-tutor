import Foundation

/// Turns microphone audio into note-on and note-off events, for playing without a MIDI keyboard.
///
/// A single note is found by its period (the YIN method), which works across the whole keyboard
/// and does not depend on how loud the fundamental is. Several notes at once cannot be told apart
/// that way, so chords are handled differently: when the music is waiting for a chord (`expected`),
/// the detector checks whether each of those notes is sounding instead of guessing from scratch.
///
/// Feed it mono samples in any chunk size. It is not thread-safe; use it from one thread.
public final class NoteDetector {
    public enum Mode {
        case normal
        /// The app itself is making sound (metronome, accompaniment) that the microphone may pick up:
        /// only notes from `expected` are reported.
        case guarded
        /// Nothing is reported, for example while the app plays the note of an on-screen key.
        case muted
    }

    public struct Event: Equatable {
        public enum Kind {
            case on
            case off
        }

        public let kind: Kind
        public let midi: Int
        public let velocity: Int
        /// When the note began, as an index into all the samples passed to `process` so far.
        /// It lies in the past: a note is only recognised some time after it starts.
        public let position: Int
    }

    /// The notes the music is waiting for, if any.
    public var expected: Set<Int> = []

    /// The notes currently reported as sounding.
    public private(set) var sounding: Set<Int> = []

    // MARK: Setup

    private let factor: Int
    private let rate: Double
    private let taps: [Float]
    private let half: Int

    private let hop: Int
    private let hopSeconds: Double
    private let hopsPerSecond: Int
    private let levelWindow: Int
    private let yinWindow: Int
    private let tauMin: Int
    private let tauMax: Int
    private let partialWindow: Int
    private let shortestChordWindow: Int
    private let keep: Int

    private static let lowestNote: Int = 33
    private static let highestNote: Int = 100

    public init(sampleRate: Double) {
        // Work at roughly 11 to 16 kHz: enough for the first partials of the top keys.
        let step: Int = max(1, Int(sampleRate / 11000))
        factor = step
        rate = sampleRate / Double(step)

        if step == 1 {
            taps = [1]
            half = 0
        } else {
            // Low-pass filter (windowed sinc) applied before dropping samples.
            let reach: Int = 6 * step
            let cutoff: Double = 0.42 / Double(step)
            var values: [Float] = []
            var sum: Double = 0
            for index in 0...(2 * reach) {
                let x: Double = Double(index - reach)
                let sinc: Double = x == 0 ? 2 * cutoff : sin(2 * Double.pi * cutoff * x) / (Double.pi * x)
                let window: Double = 0.54 - 0.46 * cos(2 * Double.pi * Double(index) / Double(2 * reach))
                values.append(Float(sinc * window))
                sum += sinc * window
            }
            taps = values.map { $0 / Float(sum) }
            half = reach
        }

        hop = max(Int((rate * 0.0116).rounded()), 16)
        hopSeconds = Double(hop) / rate
        hopsPerSecond = max(Int((1 / hopSeconds).rounded()), 1)
        levelWindow = Int(rate * 0.035)
        yinWindow = Int(rate * 0.040)
        tauMin = max(2, Int(rate / 2400))
        tauMax = Int(rate / 62) + 2
        partialWindow = Int(rate * 0.093)
        shortestChordWindow = Int(rate * 0.070)
        keep = max(partialWindow, yinWindow + tauMax) + hop

        inBuffer = Array(repeating: 0, count: half)
        inBase = -half
        difference = Array(repeating: 0, count: tauMax + 1)
        normalized = Array(repeating: 1, count: tauMax + 1)
    }

    // MARK: State

    private var inBuffer: [Float]
    /// Input position of `inBuffer[0]`.
    private var inBase: Int
    private var produced: Int = 0

    private var buffer: [Float] = []
    /// Position (in reduced-rate samples) of `buffer[0]`.
    private var bufferBase: Int = 0
    private var sinceHop: Int = 0
    private var hopIndex: Int = 0

    private var difference: [Float]
    private var normalized: [Float]

    // Loudness
    private var loudness = RiseTracker(margin: 2.5, smallestRise: 4)
    private var brightness = RiseTracker(margin: 4, smallestRise: 6)
    private var secondMinima: [Double] = []
    private var currentMinimum: Double = Double.infinity
    private var hopsInSecond: Int = 0
    private var quietHops: Int = 0
    private var peak: Double = -120

    // Single-note tracking
    private var candidate: Int? = nil
    private var candidateCount: Int = 0
    private var candidatePosition: Int = 0
    private var powerHistory: [(hop: Int, note: Int, power: Float)] = []

    /// Notices when a level jumps above where it was heading. The comparison is with a slowly
    /// falling envelope from a few hops back, so that the beating of a held chord, which only ever
    /// returns to its earlier level, is not mistaken for a new attack.
    private struct RiseTracker {
        let margin: Double
        let smallestRise: Double
        private var envelope: Double = -120
        private var envelopes: [Double] = []
        private var values: [Double] = []

        init(margin: Double, smallestRise: Double) {
            self.margin = margin
            self.smallestRise = smallestRise
        }

        private var jumping: Bool = false

        /// Returns true at the start of a jump.
        mutating func add(_ value: Double, hopSeconds: Double) -> Bool {
            let lag: Int = 4
            var above: Bool = false
            if envelopes.count >= lag, let low = values.min() {
                let earlier: Double = envelopes[envelopes.count - lag] - 30 * hopSeconds * Double(lag)
                above = value > earlier + margin && value - low >= smallestRise
            }
            let jumped: Bool = above && !jumping
            jumping = above
            envelope = max(value, envelope - 30 * hopSeconds)
            envelopes.append(envelope)
            values.append(value)
            if envelopes.count > 8 { envelopes.removeFirst() }
            if values.count > 8 { values.removeFirst() }
            return jumped
        }
    }

    /// A sudden rise in loudness: something was struck.
    private struct Attack {
        var position: Int
        var hop: Int
        var guarded: Bool
        var emitted: Set<Int> = []
        var chordFound: Bool = false
        var presence: [Int: Int] = [:]
    }

    private var attack: Attack? = nil
    private var lastOn: [Int: Int] = [:]
    /// Notes that were dropped because they had become very quiet.
    private var faded: Set<Int> = []
    private var lastAttackHop: Int = -1000

    // MARK: Input

    public func process(_ samples: [Float], mode: Mode = .normal) -> [Event] {
        return samples.withUnsafeBufferPointer { process($0, mode: mode) }
    }

    public func process(_ samples: UnsafeBufferPointer<Float>, mode: Mode = .normal) -> [Event] {
        var events: [Event] = []
        inBuffer.append(contentsOf: samples)

        var reduced: [Float] = []
        inBuffer.withUnsafeBufferPointer { input in
            taps.withUnsafeBufferPointer { filter in
                while produced * factor + half < inBase + input.count {
                    let start: Int = produced * factor - half - inBase
                    var sum: Float = 0
                    for index in 0..<filter.count {
                        sum += input[start + index] * filter[index]
                    }
                    reduced.append(sum)
                    produced += 1
                }
            }
        }
        let used: Int = produced * factor - half - inBase
        if used > 0 {
            inBuffer.removeFirst(used)
            inBase += used
        }

        for value in reduced {
            buffer.append(value)
            sinceHop += 1
            if sinceHop >= hop {
                sinceHop = 0
                analyze(mode: mode, events: &events)
            }
        }
        if buffer.count > 4 * keep {
            let extra: Int = buffer.count - keep
            buffer.removeFirst(extra)
            bufferBase += extra
        }
        return events
    }

    /// Forgets everything that is sounding, without reporting note-offs.
    public func reset() {
        sounding = []
        attack = nil
        candidate = nil
        candidateCount = 0
        powerHistory = []
        quietHops = 0
        faded = []
    }

    // MARK: Analysis

    private func analyze(mode: Mode, events: inout [Event]) {
        hopIndex += 1
        guard buffer.count >= keep else { return }
        let total: Int = bufferBase + buffer.count
        let level: Double = levelNow()

        // The quietest moment of the last half minute is taken as the room's background noise.
        currentMinimum = min(currentMinimum, level)
        hopsInSecond += 1
        if hopsInSecond >= hopsPerSecond {
            secondMinima.append(currentMinimum)
            if secondMinima.count > 30 { secondMinima.removeFirst() }
            currentMinimum = Double.infinity
            hopsInSecond = 0
        }
        let background: Double = min(secondMinima.min() ?? Double.infinity, currentMinimum)
        let gate: Double = min(max(background + 10, -62), -35)

        // A hammer blow adds more to the high partials than to the overall loudness, so both are watched.
        let louder: Bool = loudness.add(level, hopSeconds: hopSeconds)
        let brighter: Bool = brightness.add(brightnessNow(), hopSeconds: hopSeconds)

        if mode == .muted {
            releaseAll(at: total, events: &events)
            attack = nil
            setCandidate(nil, total: total)
            return
        }

        quietHops = level < gate ? quietHops + 1 : 0
        if quietHops >= 4 {
            releaseAll(at: total, events: &events)
            attack = nil
            setCandidate(nil, total: total)
            return
        }
        if !sounding.isEmpty {
            peak = max(peak, level)
            if level < peak - 40 {
                // Faded away, though its tail may go on for a while yet.
                faded = sounding
                releaseAll(at: total, events: &events)
            }
        }

        if level >= gate && (louder || brighter) && hopIndex - lastAttackHop >= 4 {
            lastAttackHop = hopIndex
            faded = []
            if var current = attack, hopIndex - current.hop < 6, current.emitted.isEmpty {
                // Still working on an attack that began a moment ago (a rolled chord).
                current.guarded = current.guarded || mode == .guarded
                attack = current
            } else {
                attack = Attack(position: (total - hop / 2) * factor, hop: hopIndex, guarded: mode == .guarded)
            }
        }
        if let current = attack, hopIndex - current.hop > 30 {
            attack = nil
        }
        let guarded: Bool = mode == .guarded || (attack?.guarded ?? false)
        let chordExpected: Bool = expected.count >= 2

        // One clear pitch?
        var single: Int? = nil
        var singlePower: Float = 0
        if level >= gate, let found = singlePitch(strict: chordExpected) {
            single = found.note
            singlePower = found.power
        }
        setCandidate(single, total: total)
        if let note = single {
            powerHistory.append((hop: hopIndex, note: note, power: singlePower))
            if powerHistory.count > 40 { powerHistory.removeFirst() }
        }

        // Are the notes of the expected chord sounding?
        if var current = attack, !expected.isEmpty, chordExpected || guarded {
            let age: Int = hopIndex - current.hop
            var vetoed: Bool = false
            if let note = single, !expected.contains(note), candidateCount >= 2, !guarded {
                // One clear note that is not part of the chord: a wrong key, not the chord.
                vetoed = true
            }
            if age >= 6 && !vetoed {
                let since: Int = total - current.position / factor
                let length: Int = min(max(since, shortestChordWindow), partialWindow)
                let present: [Int] = notesPresent(among: expected, length: length)
                for note in expected {
                    current.presence[note] = present.contains(note) ? current.presence[note, default: 0] + 1 : 0
                }
                for note in expected.sorted() where current.presence[note, default: 0] >= 2 && !current.emitted.contains(note) {
                    if !current.chordFound {
                        for other in sounding.sorted() where !expected.contains(other) {
                            turnOff(other, at: total, events: &events)
                        }
                    }
                    turnOn(note, position: current.position, level: level, total: total, events: &events)
                    current.emitted.insert(note)
                    current.chordFound = true
                }
            }
            attack = current
        }

        // Report the single note once it has held steady.
        guard let note = candidate, candidateCount >= 3 else { return }
        let wanted: Bool = expected.contains(note)
        let keepOthers: Bool = wanted && chordExpected

        if !sounding.contains(note) {
            var allowed: Bool = true
            let fresh: Bool = attack.map { $0.emitted.isEmpty || keepOthers } ?? false
            if !fresh {
                // Nothing was struck, yet the pitch seems to have changed. That happens (a quiet
                // legato note), but more often a fading sound is being misread: a chord cannot be
                // followed this way at all, and a dying note tends to jump to one of its partials.
                let intervals: Set<Int> = [12, 19, 24]
                let partial: Bool = sounding.contains { intervals.contains(abs($0 - note)) }
                if sounding.count >= 2 || partial || candidateCount < 6 || faded.contains(note) {
                    allowed = false
                }
            }
            if !wanted {
                if guarded {
                    allowed = false
                } else if let current = attack {
                    // Give the chord check time to finish before calling this a wrong note.
                    if current.chordFound || (chordExpected && hopIndex - current.hop < 14) {
                        allowed = false
                    }
                }
            }
            guard allowed else { return }
            if !keepOthers {
                releaseAll(at: total, events: &events)
            }
            var position: Int = candidatePosition
            if let current = attack, hopIndex - current.hop <= 20, current.emitted.isEmpty || keepOthers {
                position = current.position
            }
            turnOn(note, position: position, level: level, total: total, events: &events)
            attack?.emitted.insert(note)
        } else if let current = attack, !current.emitted.contains(note), hopIndex - current.hop >= 5, wanted || !guarded {
            // The same key struck again.
            guard grewLouder(note, power: singlePower, since: current.hop) else { return }
            if !keepOthers {
                for other in sounding.sorted() where other != note {
                    turnOff(other, at: total, events: &events)
                }
            }
            turnOn(note, position: current.position, level: level, total: total, events: &events)
            attack?.emitted.insert(note)
        }
    }

    private func setCandidate(_ note: Int?, total: Int) {
        if note == candidate {
            candidateCount += 1
        } else {
            candidate = note
            candidateCount = 1
            candidatePosition = max(total - (yinWindow + tauMax) / 2, 0) * factor
        }
    }

    private func grewLouder(_ note: Int, power: Float, since attackHop: Int) -> Bool {
        var before: Float? = nil
        for entry in powerHistory.reversed() where entry.hop < attackHop {
            if attackHop - entry.hop <= 3 && entry.note == note {
                before = entry.power
            }
            break
        }
        guard let earlier = before else { return true }
        return power >= 1.6 * earlier
    }

    private func turnOn(_ note: Int, position: Int, level: Double, total: Int, events: inout [Event]) {
        // Nobody repeats a key this fast; it is the same note noticed twice.
        if let last = lastOn[note], hopIndex - last < 10 { return }
        lastOn[note] = hopIndex
        if sounding.contains(note) {
            events.append(Event(kind: .off, midi: note, velocity: 0, position: total * factor))
        }
        sounding.insert(note)
        peak = sounding.count == 1 ? level : max(peak, level)
        let velocity: Int = min(max(Int((level + 60) * 2.2), 20), 127)
        events.append(Event(kind: .on, midi: note, velocity: velocity, position: min(position, total * factor)))
    }

    private func turnOff(_ note: Int, at total: Int, events: inout [Event]) {
        guard sounding.remove(note) != nil else { return }
        events.append(Event(kind: .off, midi: note, velocity: 0, position: total * factor))
    }

    private func releaseAll(at total: Int, events: inout [Event]) {
        for note in sounding.sorted() {
            events.append(Event(kind: .off, midi: note, velocity: 0, position: total * factor))
        }
        sounding = []
        peak = -120
    }

    // MARK: Measurements

    private static func frequency(of note: Int) -> Double {
        return 440 * pow(2, Double(note - 69) / 12)
    }

    /// Loudness of the last few hundredths of a second, in dB relative to full scale.
    private func levelNow() -> Double {
        let start: Int = buffer.count - levelWindow
        var sum: Float = 0
        buffer.withUnsafeBufferPointer { data in
            for index in start..<data.count {
                sum += data[index] * data[index]
            }
        }
        return 10 * log10(Double(sum) / Double(levelWindow) + 1e-12)
    }

    /// The same for the change from one sample to the next, which favours the high partials.
    private func brightnessNow() -> Double {
        let start: Int = buffer.count - levelWindow
        var sum: Float = 0
        buffer.withUnsafeBufferPointer { data in
            for index in start..<data.count {
                let change: Float = data[index] - data[index - 1]
                sum += change * change
            }
        }
        return 10 * log10(Double(sum) / Double(levelWindow) + 1e-12)
    }

    /// The note being played if the sound has one clear pitch.
    /// `strict` is used while a chord is expected: two or three notes together can repeat with the
    /// period of a much lower note, so that note is only believed if its own fundamental is there.
    private func singlePitch(strict: Bool) -> (note: Int, power: Float)? {
        guard let period = yinPeriod() else { return nil }
        var pitch: Double = rate / period
        var note: Int = Int((69 + 12 * log2(pitch / 440)).rounded())
        guard note >= NoteDetector.lowestNote && note <= NoteDetector.highestNote else { return nil }

        if pitch > 700 {
            // Up here a period is only a few samples long; let the spectrum settle between neighbours.
            var best: Int = note
            var bestAmplitude: Float = amplitude(at: NoteDetector.frequency(of: note), length: partialWindow)
            for other in [note - 1, note + 1] {
                let value: Float = amplitude(at: NoteDetector.frequency(of: other), length: partialWindow)
                if value > 1.5 * bestAmplitude {
                    best = other
                    bestAmplitude = value
                }
            }
            if best != note {
                note = best
                pitch = NoteDetector.frequency(of: best)
            }
        }

        var partials: [Float] = []
        for harmonic in 1...6 {
            partials.append(amplitude(at: pitch * Double(harmonic), length: partialWindow))
        }
        guard let strongest = partials.max(), strongest > 0 else { return nil }
        var real: Bool = partials[0] >= 0.1 * strongest
        if !real && !strict {
            // Small microphones and speakers lose the fundamental of low notes.
            real = partials[1] >= 0.05 * strongest && partials[2] >= 0.05 * strongest && partials[4] >= 0.05 * strongest
        }
        guard real else { return nil }
        var power: Float = 0
        for value in partials {
            power += value * value
        }
        return (note, power)
    }

    /// The period of the sound in samples, by the YIN method, or nil if it is not periodic enough.
    private func yinPeriod() -> Double? {
        let span: Int = yinWindow + tauMax
        let offset: Int = buffer.count - span
        let window: Int = yinWindow
        let longest: Int = tauMax
        buffer.withUnsafeBufferPointer { data in
            difference.withUnsafeMutableBufferPointer { result in
                result[0] = 0
                for tau in 1...longest {
                    var sum: Float = 0
                    for index in 0..<window {
                        let delta: Float = data[offset + index] - data[offset + index + tau]
                        sum += delta * delta
                    }
                    result[tau] = sum
                }
            }
        }
        var running: Float = 0
        for tau in 1...longest {
            running += difference[tau]
            normalized[tau] = running > 0 ? difference[tau] * Float(tau) / running : 1
        }

        var tau: Int = tauMin
        var found: Int = -1
        while tau < longest {
            if normalized[tau] < 0.15 {
                while tau + 1 < longest && normalized[tau + 1] < normalized[tau] {
                    tau += 1
                }
                found = tau
                break
            }
            tau += 1
        }
        guard found > 1 && found < longest - 1 else { return nil }
        let before: Float = normalized[found - 1]
        let here: Float = normalized[found]
        let after: Float = normalized[found + 1]
        let curve: Float = before - 2 * here + after
        let shift: Float = curve > 0 ? 0.5 * (before - after) / curve : 0
        return Double(found) + Double(min(max(shift, -1), 1))
    }

    /// How strong a sine of this frequency is in the last `length` samples (Hann window).
    private func amplitude(at frequency: Double, length: Int) -> Float {
        guard frequency < 0.45 * rate, length > 8, buffer.count >= length else { return 0 }
        let offset: Int = buffer.count - length
        let turn: Double = 2 * Double.pi * frequency / rate
        let turnCos: Double = cos(turn)
        let turnSin: Double = sin(turn)
        let windowTurn: Double = 2 * Double.pi / Double(length)
        let windowCos: Double = cos(windowTurn)
        let windowSin: Double = sin(windowTurn)
        var c: Double = 1
        var s: Double = 0
        var wc: Double = 1
        var ws: Double = 0
        var real: Double = 0
        var imaginary: Double = 0
        buffer.withUnsafeBufferPointer { data in
            for index in 0..<length {
                let value: Double = Double(data[offset + index]) * (0.5 - 0.5 * wc)
                real += value * c
                imaginary -= value * s
                let nextC: Double = c * turnCos - s * turnSin
                s = s * turnCos + c * turnSin
                c = nextC
                let nextWC: Double = wc * windowCos - ws * windowSin
                ws = ws * windowCos + wc * windowSin
                wc = nextWC
            }
        }
        return Float(4 * (real * real + imaginary * imaginary).squareRoot() / Double(length))
    }

    /// Mean power of the last `length` samples under the same window as `amplitude`.
    private func windowedPower(length: Int) -> Float {
        let offset: Int = buffer.count - length
        var sum: Double = 0
        var weight: Double = 0
        buffer.withUnsafeBufferPointer { data in
            for index in 0..<length {
                let window: Double = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(length))
                let value: Double = Double(data[offset + index]) * window
                sum += value * value
                weight += window * window
            }
        }
        return Float(sum / max(weight, 1e-12))
    }

    /// Which of these notes are sounding. A note counts if both its fundamental and its
    /// second partial stand out; pianos are rarely in perfect tune, so each is looked for a little
    /// to either side as well.
    private func notesPresent(among notes: Set<Int>, length: Int) -> [Int] {
        guard buffer.count >= length else { return [] }
        var measured: [(note: Int, first: Float, second: Float, hasSecond: Bool)] = []
        var strongest: Float = 0
        for note in notes {
            let pitch: Double = NoteDetector.frequency(of: note)
            var first: Float = 0
            var second: Float = 0
            for cents in [-20.0, 0.0, 20.0] {
                let tuned: Double = pitch * pow(2, cents / 1200)
                first = max(first, amplitude(at: tuned, length: length))
                second = max(second, amplitude(at: 2 * tuned, length: length))
            }
            if pitch >= 180 {
                // The peak has to be on this key, not spilling over from the key next to it.
                // (Further down the keys are too close together in pitch to tell this way.)
                let below: Float = amplitude(at: NoteDetector.frequency(of: note - 1), length: length)
                let above: Float = amplitude(at: NoteDetector.frequency(of: note + 1), length: length)
                if first < 0.8 * max(below, above) {
                    first = 0
                }
            }
            let hasSecond: Bool = 2 * pitch * 1.02 < 0.45 * rate
            measured.append((note, first, second, hasSecond))
            strongest = max(strongest, first, second)
        }
        // The chord's partials have to account for a fair share of the sound.
        guard strongest > 0, strongest * strongest / 2 >= 0.03 * windowedPower(length: length) else { return [] }
        var present: [Int] = []
        for entry in measured {
            if entry.first >= 0.1 * strongest && (!entry.hasSecond || entry.second >= 0.03 * strongest) {
                present.append(entry.note)
            }
        }
        return present
    }
}

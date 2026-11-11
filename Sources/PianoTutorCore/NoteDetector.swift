import Foundation

/// Turns microphone audio into note-on and note-off events, for playing without a MIDI keyboard.
///
/// The notes the music is waiting for (`expected`) are looked for directly, each at its own
/// pitch. That finds chords, and it still works while other sounds are going on. Any other note
/// is found by the period of the sound (the YIN method), which needs the piano to be the only
/// thing sounding and cannot tell several notes apart.
///
/// A room is rarely quiet, and a voice has a pitch too. So a note only counts if it looks like a
/// piano: it begins with an attack, and it then stays exactly on one key's pitch, which speech,
/// shouting and even most singing do not. A note that is not expected, and would be shown as a
/// mistake, has to pass the strictest form of that test.
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
    private let warmUp: Int

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
        warmUp = max(partialWindow, yinWindow + tauMax) + hop
        keep = warmUp + 32 * hop

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
    /// The measured pitch (in fractional keys) for each hop the candidate has lasted.
    private var candidatePitches: [Double] = []
    private var candidateInTune: [Bool] = []
    /// The same, measured precisely from the phase of the fundamental, in cents off the key.
    private var candidateTuning: [Double] = []
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
        /// Every jump in loudness that belongs to this attack, the first one included.
        var strikes: [(hop: Int, position: Int)]

        init(position: Int, hop: Int, guarded: Bool) {
            self.position = position
            self.hop = hop
            self.guarded = guarded
            self.strikes = [(hop: hop, position: position)]
        }

        /// When a note that was first noticed at `hop` must have been struck.
        func position(before hop: Int) -> Int {
            return strikes.last(where: { $0.hop <= hop })?.position ?? position
        }

        var emitted: Set<Int> = []
        var chordFound: Bool = false
        var presence: [Int: Int] = [:]
        var strength: [Int: Float] = [:]
        /// How far off its key each expected note sounded at the last hop, in cents.
        var tuning: [Int: Double] = [:]
        /// How strong each expected note was before the attack.
        var before: [Int: Float] = [:]
        /// Loudness at each hop since the attack.
        var levels: [Double] = []
    }

    private var attack: Attack? = nil
    private var lastOn: [Int: Int] = [:]
    /// Notes that were dropped because they had become very quiet.
    private var faded: Set<Int> = []
    private var lastAttackHop: Int = -1000
    private var jumpHop: Int = -1000

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
        candidatePitches = []
        candidateInTune = []
        candidateTuning = []
        powerHistory = []
        quietHops = 0
        faded = []
    }

    // MARK: Analysis

    private func analyze(mode: Mode, events: inout [Event]) {
        hopIndex += 1
        guard buffer.count >= warmUp else { return }
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
        // A quiet note starts from below the gate; the jump is remembered until it gets above it.
        if louder || brighter {
            jumpHop = hopIndex
        }

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

        if level >= gate && hopIndex - jumpHop <= 3 && hopIndex - lastAttackHop >= 4 {
            jumpHop = -1000
            lastAttackHop = hopIndex
            faded = []
            let position: Int = (total - hop / 2) * factor
            if var current = attack, hopIndex - current.hop < 16, current.emitted.isEmpty {
                // Still working out what an attack a moment ago was (a rolled chord, an echo,
                // or a shout just before the key went down). Remember this one as well.
                current.guarded = current.guarded || mode == .guarded
                current.strikes.append((hop: hopIndex, position: position))
                attack = current
            } else {
                attack = Attack(position: position, hop: hopIndex, guarded: mode == .guarded)
            }
        }
        if let current = attack, hopIndex - (current.strikes.last?.hop ?? current.hop) > 30 {
            attack = nil
        }
        let guarded: Bool = mode == .guarded || (attack?.guarded ?? false)
        let chordExpected: Bool = expected.count >= 2
        attack?.levels.append(level)

        // One clear pitch?
        var single: SinglePitch? = nil
        if level >= gate {
            single = singlePitch(strict: chordExpected)
        }
        setCandidate(single, total: total)
        if let found = single {
            powerHistory.append((hop: hopIndex, note: found.note, power: found.power))
            if powerHistory.count > 40 { powerHistory.removeFirst() }
        }

        // Something was struck: is it one of the notes the music is waiting for? Each of them is
        // looked for at its own pitch, which still works while people are talking over the piano.
        if var current = attack, !expected.isEmpty {
            let age: Int = hopIndex - current.hop
            for note in expected where current.before[note] == nil {
                // How strong the note was just before the attack, in case it was still ringing.
                let back: Int = min((age + 1) * hop, buffer.count - partialWindow)
                current.before[note] = fundamental(of: note, length: partialWindow, back: back)
            }
            var vetoed: Bool = false
            if let found = single, !expected.contains(found.note), candidateCount >= 2, !guarded {
                // One clear lower note whose partials are the expected notes: the wrong key
                // (C3 instead of C4 and G4), not the expected ones.
                let partials: Set<Int> = [12, 19, 24, 28, 31, 34, 36]
                vetoed = expected.allSatisfy { partials.contains($0 - found.note) }
            }
            if age >= 6 && !vetoed {
                let since: Int = total - current.position / factor
                let length: Int = min(max(since, shortestChordWindow), partialWindow)
                let present: [Int: Float] = notesPresent(among: expected, length: length)
                for note in expected {
                    guard let strength = present[note], strength >= 1.25 * (current.before[note] ?? 0),
                          let tuning = centsOffKey(note, length: length), abs(tuning) <= 33 || note < 43,
                          !isOvertone(note, strength: strength, length: length) else {
                        current.presence[note] = 0
                        current.strength[note] = nil
                        current.tuning[note] = nil
                        continue
                    }
                    // A piano string keeps sounding evenly and at one pitch;
                    // a voice passing through the pitch does neither.
                    var even: Bool = true
                    if let last = current.strength[note], strength > 1.4 * last || strength < 0.5 * last {
                        even = false
                    }
                    if let last = current.tuning[note], abs(tuning - last) > 6, note >= 43 {
                        even = false
                    }
                    current.presence[note] = even ? current.presence[note, default: 0] + 1 : 1
                    current.strength[note] = strength
                    current.tuning[note] = tuning
                }
                for note in expected.sorted() where current.presence[note, default: 0] >= 4 && !current.emitted.contains(note) {
                    if !current.chordFound {
                        for other in sounding.sorted() where !expected.contains(other) {
                            turnOff(other, at: total, events: &events)
                        }
                    }
                    // It has been there for four hops, and needed a few more to show.
                    turnOn(note, position: current.position(before: hopIndex - 7), level: level, total: total, events: &events)
                    current.emitted.insert(note)
                    current.chordFound = true
                }
            }
            attack = current
        }

        // Otherwise, one clear pitch that began with an attack is a note.
        guard let found = single, let note = candidate, let current = attack else { return }
        let age: Int = hopIndex - current.hop
        let wanted: Bool = expected.contains(note)
        let keepOthers: Bool = wanted && chordExpected
        guard !current.emitted.contains(note), current.emitted.isEmpty || keepOthers else { return }

        if wanted {
            guard candidateCount >= 3, pitchSpread(last: 3) <= 0.35, tuningIsSteady(last: 3) else { return }
        } else {
            // A note nobody asked for is shown as a mistake, so it has to be beyond doubt a piano
            // and not a voice: struck, then fading, at a steady pitch that is in tune with a key.
            guard !guarded, !current.chordFound else { return }
            let hops: Int = 7
            guard age >= (chordExpected ? 14 : hops + 2), candidateCount >= hops else { return }
            guard candidateInTune.suffix(hops - 1).allSatisfy({ $0 }), pitchSpread(last: hops - 1) <= 0.1,
                  tuningIsSteady(last: hops - 1) else { return }
            guard wasStruck(current.levels) else { return }
        }
        guard grewLouder(note, power: found.power, since: current.hop) else { return }

        if !keepOthers {
            for other in sounding.sorted() where other != note {
                turnOff(other, at: total, events: &events)
            }
        }
        turnOn(note, position: current.position(before: hopIndex - candidateCount), level: level, total: total, events: &events)
        attack?.emitted.insert(note)
    }

    /// A struck string is loudest almost at once and fades from there; a voice swells.
    /// (Some later growth is allowed for: a room's echoes add up for a moment.)
    private func wasStruck(_ levels: [Double]) -> Bool {
        guard levels.count > 5, let early = levels.prefix(5).max(), let later = levels.dropFirst(5).max() else { return true }
        return later <= early + 5
    }

    /// Whether the candidate has stayed on its key, at one pitch, for the last few hops.
    /// A piano string does; a voice, even a sung note, drifts by more than this.
    private func tuningIsSteady(last count: Int) -> Bool {
        let recent = candidateTuning.suffix(count)
        guard recent.count == count, let low = recent.min(), let high = recent.max() else { return false }
        if (candidate ?? 0) < 43 { return true }
        return low >= -33 && high <= 33 && high - low <= 8
    }

    /// How far the pitch has wandered over the last few hops, in semitones.
    private func pitchSpread(last count: Int) -> Double {
        let recent = candidatePitches.suffix(count)
        guard let low = recent.min(), let high = recent.max() else { return 0 }
        return high - low
    }

    private func setCandidate(_ found: SinglePitch?, total: Int) {
        if found?.note == candidate {
            candidateCount += 1
        } else {
            candidate = found?.note
            candidateCount = 1
            candidatePitches = []
            candidateInTune = []
            candidateTuning = []
        }
        if let found = found {
            candidatePitches.append(found.exact)
            candidateInTune.append(found.inTune)
            candidateTuning.append(centsOffKey(found.note, length: partialWindow) ?? 100)
            if candidatePitches.count > 12 {
                candidatePitches.removeFirst()
                candidateInTune.removeFirst()
                candidateTuning.removeFirst()
            }
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

    private struct SinglePitch {
        let note: Int
        let power: Float
        /// The pitch in fractional keys, where it can be measured that finely.
        let exact: Double
        let inTune: Bool
    }

    /// The note being played if the sound has one clear pitch.
    /// `strict` is used while a chord is expected: two or three notes together can repeat with the
    /// period of a much lower note, so that note is only believed if its own fundamental is there.
    private func singlePitch(strict: Bool) -> SinglePitch? {
        guard let period = yinPeriod() else { return nil }
        var pitch: Double = rate / period
        let exact: Double = 69 + 12 * log2(pitch / 440)
        var note: Int = Int(exact.rounded())
        guard note >= NoteDetector.lowestNote && note <= NoteDetector.highestNote else { return nil }
        var inTune: Bool = abs(exact - Double(note)) <= 0.3
        let high: Bool = pitch > 700

        if high {
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
            // A period this short cannot be timed finely, but the spectrum can tell a pitch that
            // sits on the key from one that is between keys or sliding about.
            let onKey: Float = amplitude(at: NoteDetector.frequency(of: note), length: partialWindow)
            let sharp: Float = amplitude(at: NoteDetector.frequency(of: note) * pow(2, 50.0 / 1200), length: partialWindow)
            let flat: Float = amplitude(at: NoteDetector.frequency(of: note) * pow(2, -50.0 / 1200), length: partialWindow)
            inTune = onKey >= 2 * max(sharp, flat)
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
        return SinglePitch(note: note, power: power, exact: high ? Double(note) : exact, inTune: inTune)
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
    /// `back` moves the window that many samples into the past.
    private func amplitude(at frequency: Double, length: Int, back: Int = 0) -> Float {
        let value = partial(at: frequency, length: length, back: back)
        return Float(4 * (value.real * value.real + value.imaginary * value.imaginary).squareRoot() / Double(length))
    }

    /// The sum behind `amplitude`: the windowed sound multiplied by a turning phase.
    private func partial(at frequency: Double, length: Int, back: Int) -> (real: Double, imaginary: Double) {
        guard frequency < 0.45 * rate, length > 8, back >= 0, buffer.count >= length + back else { return (0, 0) }
        let offset: Int = buffer.count - length - back
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
        return (real, imaginary)
    }

    /// How far the sound near this key's pitch is from the key itself, in hundredths of a semitone.
    /// The spectrum of so short a stretch is far too blurred to say, but how much the partial's
    /// phase moves on from one hop to the next gives its frequency precisely. This is what tells
    /// a piano from a voice that happens to pass by the same pitch.
    private func centsOffKey(_ note: Int, length: Int) -> Double? {
        let pitch: Double = NoteDetector.frequency(of: note)
        guard buffer.count >= length + hop else { return nil }
        let now = partial(at: pitch, length: length, back: 0)
        let earlier = partial(at: pitch, length: length, back: hop)
        let expectedTurn: Double = 2 * Double.pi * pitch * Double(hop) / rate
        var difference: Double = atan2(now.imaginary, now.real) - atan2(earlier.imaginary, earlier.real) - expectedTurn
        difference -= 2 * Double.pi * (difference / (2 * Double.pi)).rounded()
        let offset: Double = difference / (2 * Double.pi * hopSeconds)
        return 1200 * log2(max(pitch + offset, 1) / pitch)
    }

    /// Whether what looks like this note is really an overtone of a lower sound: a deeper voice,
    /// or the same key an octave down. Then there is as much sound at a half or a third of its pitch.
    private func isOvertone(_ note: Int, strength: Float, length: Int) -> Bool {
        let pitch: Double = NoteDetector.frequency(of: note)
        for (divisor, interval) in [(2.0, 12), (3.0, 19)] {
            // Unless that lower note is itself being played.
            if expected.contains(note - interval) || sounding.contains(note - interval) { continue }
            if pitch / divisor < 70 { continue }
            if amplitude(at: pitch / divisor, length: length) >= 0.7 * strength {
                return true
            }
        }
        return false
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

    /// The strength of a note's fundamental, allowing for a piano that is a little out of tune.
    private func fundamental(of note: Int, length: Int, back: Int = 0) -> Float {
        let pitch: Double = NoteDetector.frequency(of: note)
        var best: Float = 0
        for cents in [-20.0, 0.0, 20.0] {
            best = max(best, amplitude(at: pitch * pow(2, cents / 1200), length: length, back: back))
        }
        return best
    }

    /// Which of these notes are sounding, with the strength of each one's fundamental. A note
    /// counts if both its fundamental and its second partial stand out; pianos are rarely in
    /// perfect tune, so each is looked for a little to either side as well.
    private func notesPresent(among notes: Set<Int>, length: Int) -> [Int: Float] {
        guard buffer.count >= length else { return [:] }
        var measured: [(note: Int, first: Float, second: Float, hasSecond: Bool)] = []
        var strongest: Float = 0
        for note in notes {
            let pitch: Double = NoteDetector.frequency(of: note)
            var first: Float = fundamental(of: note, length: length)
            var second: Float = 0
            for cents in [-20.0, 0.0, 20.0] {
                second = max(second, amplitude(at: 2 * pitch * pow(2, cents / 1200), length: length))
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
        // The notes' partials have to account for a fair share of the sound.
        guard strongest > 0, strongest * strongest / 2 >= 0.01 * windowedPower(length: length) else { return [:] }
        var present: [Int: Float] = [:]
        for entry in measured {
            if entry.first >= 0.1 * strongest && (!entry.hasSecond || entry.second >= 0.03 * strongest) {
                present[entry.note] = entry.first
            }
        }
        return present
    }
}

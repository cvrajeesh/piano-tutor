import SwiftUI
import Combine
import PianoTutorCore

/// A key to light up on the on-screen keyboard.
struct KeyTarget: Equatable {
    let hand: Hand
    let finger: Int?
}

enum NoteVisual {
    case upcoming
    /// The note the music is waiting for.
    case active
    case hit
    case missed
    /// Played by the app (the hand that is not being practised).
    case passive
}

struct StaffOverlay {
    var countIn: Int? = nil
    var feedbackText: String? = nil
    var feedbackColor: Color = .clear
    var feedbackAge: Double = 0
}

/// What the staff needs to know on every frame.
protocol StaffSource: AnyObject {
    func viewBeat(at time: TimeInterval) -> Double
    func visual(forEvent id: Int) -> NoteVisual
    func overlay(at time: TimeInterval) -> StaffOverlay
}

/// A staff that does not move, used for examples and free play.
final class StaticStaffSource: StaffSource {
    var beat: Double

    init(beat: Double = -0.6) {
        self.beat = beat
    }

    func viewBeat(at time: TimeInterval) -> Double {
        return beat
    }

    func visual(forEvent id: Int) -> NoteVisual {
        return .upcoming
    }

    func overlay(at time: TimeInterval) -> StaffOverlay {
        return StaffOverlay()
    }
}

struct SessionConfig {
    enum Mode {
        /// The music waits for the right notes.
        case wait
        /// The music runs in time with the metronome and is scored.
        case tempo
    }

    var score: Score
    var mode: Mode
    var hands: Set<Hand>
    var tempoScale: Double = 1.0
    var metronome: Bool = true
    var noteNames: Bool = true
    var keyHints: Bool = true
}

/// Runs one exercise: listens to the keyboard, judges the notes and drives the staff.
final class PlaySession: ObservableObject, StaffSource {
    enum Phase {
        case idle
        case running
        case finished
    }

    let config: SessionConfig
    let layout: StaffLayout

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var targets: [Int: KeyTarget] = [:]
    @Published private(set) var wrongKeys: Set<Int> = []
    @Published private(set) var goodKeys: Set<Int> = []
    @Published private(set) var result: PerformanceSummary?
    @Published private(set) var streak: Int = 0
    @Published private(set) var progress: Double = 0

    private let audio: AudioEngine
    private let scheduler: EventScheduler
    private let input: InputHub
    private let mic: MicrophoneInput
    private let timingOffset: TimeInterval
    private let inputLag: TimeInterval
    private let micRightNotesOnly: Bool
    private let micRange: ClosedRange<Int>?
    private let groups: [NoteGroup]

    private var trainer: StepTrainer?
    private var judge: PerformanceJudge?
    private var subscription: AnyCancellable?
    private var timer: Timer?
    private var visuals: [Int: NoteVisual] = [:]
    private var generation: Int = 0

    // Tempo mode timing
    private var secondsPerBeat: Double = 1
    private var countInBeats: Double = 0
    private var zeroTime: TimeInterval = 0
    private var finalBeat: Double = 0
    private var nextGroup: Int = 0
    private var shownGroup: Int = -1

    // Wait mode scrolling
    private var shownBeat: Double = -1
    private var lastFrame: TimeInterval = 0

    private var feedbackText: String?
    private var feedbackColor: Color = .clear
    private var feedbackTime: TimeInterval = 0

    init(config: SessionConfig, model: AppModel) {
        self.config = config
        self.layout = StaffLayout(score: config.score)
        self.audio = model.audio
        self.scheduler = model.scheduler
        self.input = model.input
        self.mic = model.mic
        self.timingOffset = model.timingOffset
        self.inputLag = model.inputLag
        self.micRightNotesOnly = model.micRightNotesOnly
        // A learner's slips land near the right keys; a "note" far outside the piece is a voice.
        self.micRange = config.score.keyRange(hands: config.hands).map { ($0.lowerBound - 4)...($0.upperBound + 4) }
        self.groups = config.score.groups(for: config.hands)
        resetVisuals()
    }

    private func resetVisuals() {
        visuals = [:]
        for note in config.score.notes where !config.hands.contains(note.hand) {
            visuals[note.id] = .passive
        }
    }

    // MARK: Lifecycle

    func start() {
        stop()
        guard !config.score.isEmpty, !groups.isEmpty else { return }
        generation += 1
        resetVisuals()
        result = nil
        streak = 0
        progress = 0
        wrongKeys = []
        goodKeys = []
        feedbackText = nil

        subscription = input.events.sink { [weak self] note in
            self?.handle(note)
        }

        switch config.mode {
        case .wait:
            trainer = StepTrainer(score: config.score, hands: config.hands)
            judge = nil
            shownBeat = (groups.first?.start ?? 0) - 1.0
            lastFrame = HostClock.now
            phase = .running
            updateWaitTargets()
        case .tempo:
            startTempo()
        }
    }

    private func startTempo() {
        let score: Score = config.score
        let scale: Double = max(config.tempoScale, 0.1)
        let spb: Double = 60.0 / (score.tempo * scale)
        let measure: Double = score.time.measureLength
        secondsPerBeat = spb
        countInBeats = score.pickup > 0 ? (2 * measure - score.pickup) : measure
        zeroTime = HostClock.now + 0.4 + countInBeats * spb
        nextGroup = 0
        shownGroup = -1
        trainer = nil
        judge = PerformanceJudge(score: score, hands: config.hands, secondsPerBeat: spb)

        var batch: [(TimeInterval, () -> Void)] = []
        let audio: AudioEngine = self.audio
        let origin: Double = score.pickup > 0 ? score.pickup : 0

        var beat: Double = -countInBeats
        while beat < score.totalBeats - 1e-6 {
            let countingIn: Bool = beat < -1e-6
            if config.metronome || countingIn {
                var phaseInMeasure: Double = (beat - origin).truncatingRemainder(dividingBy: measure)
                if phaseInMeasure < 0 { phaseInMeasure += measure }
                let accent: Bool = phaseInMeasure < 1e-6 || measure - phaseInMeasure < 1e-6
                batch.append((zeroTime + beat * spb, { audio.click(accent: accent) }))
            }
            beat += 1
        }

        // The microphone hears the clicks too; it is told when to expect them.
        var appSounds: [ClosedRange<TimeInterval>] = batch.map { ($0.0 - 0.06)...($0.0 + 0.15) }

        // The app plays the hand that is not being practised.
        for note in score.notes where !config.hands.contains(note.hand) {
            let onTime: TimeInterval = zeroTime + note.start * spb
            let offTime: TimeInterval = max(zeroTime + (note.start + note.duration) * spb - 0.03, onTime)
            for midi in note.midiNotes {
                batch.append((onTime, { audio.noteOn(midi, velocity: 72) }))
                batch.append((offTime, { audio.noteOff(midi) }))
            }
            appSounds.append((onTime - 0.06)...(offTime + 0.25))
        }
        scheduler.schedule(batch)
        mic.setGuards(appSounds)

        let newTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        phase = .running
        tick()
    }

    func stop() {
        generation += 1
        timer?.invalidate()
        timer = nil
        subscription?.cancel()
        subscription = nil
        scheduler.cancelAll()
        audio.allNotesOff()
        mic.setGuards([])
        input.expectedNotes = []
        if phase == .running {
            phase = .idle
        }
        if !targets.isEmpty { targets = [:] }
        if !wrongKeys.isEmpty { wrongKeys = [] }
        if !goodKeys.isEmpty { goodKeys = [] }
    }

    private func finish() {
        guard phase == .running else { return }
        finalBeat = config.mode == .tempo ? (HostClock.now - zeroTime) / secondsPerBeat : config.score.totalBeats
        timer?.invalidate()
        timer = nil
        scheduler.cancelAll()
        mic.setGuards([])
        input.expectedNotes = []
        targets = [:]
        progress = 1
        if config.mode == .wait {
            result = trainer?.summary
        } else {
            result = judge?.summary
        }
        phase = .finished
    }

    // MARK: Input

    private func handle(_ note: NoteInput) {
        guard phase == .running else { return }
        switch note.kind {
        case .off:
            if wrongKeys.contains(note.midi) { wrongKeys.remove(note.midi) }
            if goodKeys.contains(note.midi) { goodKeys.remove(note.midi) }
            trainer?.noteOff(note.midi)
        case .on:
            switch config.mode {
            case .wait: handleWait(note)
            case .tempo: handleTempo(note)
            }
        }
    }

    /// Whether a note that is not in the music should be shown as a mistake. What the microphone
    /// hears is not always the piano, so its wrong notes are only believed when they are plausible.
    private func believable(_ note: NoteInput) -> Bool {
        guard note.source == .microphone else { return true }
        if micRightNotesOnly { return false }
        if let range = micRange, !range.contains(note.midi) { return false }
        return true
    }

    private func handleWait(_ note: NoteInput) {
        guard let trainer = trainer, let group = trainer.current else { return }
        if !group.midiNotes.contains(note.midi) && !believable(note) { return }
        let response: StepTrainer.Response = trainer.noteOn(note.midi)
        switch response {
        case .wrong:
            wrongKeys.insert(note.midi)
            streak = 0
            setFeedback(String(localized: "Not that one", comment: "Feedback on the staff when a wrong key is pressed in practice mode"), Theme.bad)
        case .partial:
            goodKeys.insert(note.midi)
        case .advanced, .finished:
            goodKeys.insert(note.midi)
            for id in group.eventIDs {
                visuals[id] = .hit
            }
            streak += 1
            progress = Double(trainer.index) / Double(max(trainer.groups.count, 1))
            updateWaitTargets()
            if response == .finished {
                let token: Int = generation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self = self, self.generation == token else { return }
                    self.finish()
                }
            }
        case .ignored:
            break
        }
    }

    private func handleTempo(_ note: NoteInput) {
        guard let judge = judge else { return }
        let time: Double = note.time - zeroTime - timingOffset
        if time < -0.3 { return }  // still counting in
        let trusted: Bool = believable(note)
        switch judge.noteOn(note.midi, at: time, countStray: trusted) {
        case .hit(let eventID, let grade, _):
            goodKeys.insert(note.midi)
            if case .hit = judge.state(ofEvent: eventID) {
                visuals[eventID] = .hit
            }
            streak += 1
            switch grade {
            case .perfect: setFeedback(String(localized: "Perfect", comment: "Feedback on the staff: a note played right on the beat"), Theme.good)
            case .early: setFeedback(String(localized: "Early", comment: "Feedback on the staff: a note played before the beat"), Theme.accent)
            case .late: setFeedback(String(localized: "Late", comment: "Feedback on the staff: a note played after the beat"), Theme.accent)
            }
        case .stray:
            guard trusted else { return }
            wrongKeys.insert(note.midi)
            streak = 0
            setFeedback(String(localized: "Wrong note", comment: "Feedback on the staff when a key that is not in the music is played in time"), Theme.bad)
        }
    }

    private func tick() {
        guard phase == .running, let judge = judge else { return }
        let elapsed: Double = HostClock.now - zeroTime

        // With the microphone a note is reported a little after it was played; wait for it.
        let missed: [Int] = judge.advance(to: elapsed - timingOffset - inputLag)
        if !missed.isEmpty {
            for id in missed {
                visuals[id] = .missed
            }
            streak = 0
            setFeedback(String(localized: "Missed", comment: "Feedback on the staff: a note that was not played"), Theme.bad)
        }

        while nextGroup < groups.count && groups[nextGroup].start * secondsPerBeat < elapsed - 0.15 {
            nextGroup += 1
        }

        // The notes due about now, for the microphone.
        var due: Set<Int> = []
        var index: Int = max(nextGroup - 2, 0)
        while index < groups.count {
            let offset: Double = groups[index].start * secondsPerBeat - (elapsed - timingOffset)
            if offset > 0.3 { break }
            if offset > -0.3 - inputLag {
                due.formUnion(groups[index].midiNotes)
            }
            index += 1
        }
        input.expectedNotes = due
        if nextGroup != shownGroup {
            shownGroup = nextGroup
            if config.keyHints && nextGroup < groups.count {
                targets = keyTargets(for: groups[nextGroup])
            } else if !targets.isEmpty {
                targets = [:]
            }
        }

        let length: Double = max(config.score.totalBeats * secondsPerBeat, 0.001)
        let fraction: Double = min(max(elapsed / length, 0), 1)
        if abs(fraction - progress) > 0.01 {
            progress = fraction
        }

        if elapsed > (config.score.totalBeats + 0.75) * secondsPerBeat {
            finish()
        }
    }

    private func updateWaitTargets() {
        guard let trainer = trainer else { return }
        if let group = trainer.current {
            for id in group.eventIDs {
                visuals[id] = .active
            }
            targets = config.keyHints ? keyTargets(for: group) : [:]
            input.expectedNotes = group.midiNotes
        } else {
            targets = [:]
            input.expectedNotes = []
        }
    }

    private func keyTargets(for group: NoteGroup) -> [Int: KeyTarget] {
        var result: [Int: KeyTarget] = [:]
        for id in group.eventIDs where id >= 0 && id < config.score.notes.count {
            let event: NoteEvent = config.score.notes[id]
            for (index, pitch) in event.pitches.enumerated() {
                result[pitch.midi] = KeyTarget(hand: event.hand, finger: event.fingers[index])
            }
        }
        return result
    }

    private func setFeedback(_ text: String, _ color: Color) {
        feedbackText = text
        feedbackColor = color
        feedbackTime = HostClock.now
    }

    // MARK: StaffSource

    func viewBeat(at time: TimeInterval) -> Double {
        switch config.mode {
        case .tempo:
            switch phase {
            case .idle: return -1.0
            case .finished: return finalBeat
            case .running: return (time - zeroTime) / secondsPerBeat
            }
        case .wait:
            let target: Double = trainer?.current?.start ?? config.score.totalBeats
            let delta: Double = min(max(time - lastFrame, 0), 0.1)
            lastFrame = time
            if phase == .idle {
                shownBeat = (groups.first?.start ?? 0) - 1.0
            } else {
                shownBeat += (target - shownBeat) * (1 - exp(-delta * 9))
            }
            return shownBeat
        }
    }

    func visual(forEvent id: Int) -> NoteVisual {
        return visuals[id] ?? .upcoming
    }

    func overlay(at time: TimeInterval) -> StaffOverlay {
        var overlay = StaffOverlay()
        if config.mode == .tempo && phase == .running {
            let beat: Double = (time - zeroTime) / secondsPerBeat
            let counted: Double = beat + countInBeats
            if beat < -0.02 && counted >= 0 {
                let perMeasure: Int = max(Int(config.score.time.measureLength.rounded()), 1)
                overlay.countIn = Int(counted.rounded(.down)) % perMeasure + 1
            }
        }
        if let text = feedbackText {
            let age: Double = time - feedbackTime
            if age < 0.8 {
                overlay.feedbackText = text
                overlay.feedbackColor = feedbackColor
                overlay.feedbackAge = age
            }
        }
        return overlay
    }
}

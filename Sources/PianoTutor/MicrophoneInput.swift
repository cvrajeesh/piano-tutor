import Foundation
import AVFoundation
import PianoTutorCore

/// Listens to a piano through the microphone and reports the notes it hears, for playing
/// without a MIDI keyboard. The listening itself is done by `NoteDetector`.
final class MicrophoneInput: ObservableObject {
    enum State: Equatable {
        case off
        /// Waiting for the user to answer the permission question.
        case asking
        case listening
        /// The user has not allowed the app to use the microphone.
        case denied
        case failed(String)
    }

    @Published private(set) var state: State = .off

    /// Called on the main thread.
    var onNote: ((NoteInput) -> Void)?

    /// Called before listening starts and after it stops, so that the audio session can be set up for recording.
    var sessionHook: ((Bool) -> Void)?

    var isListening: Bool {
        return state == .listening
    }

    private let engine = AVAudioEngine()
    private var wanted: Bool = false
    private var tapInstalled: Bool = false
    private var observer: NSObjectProtocol?

    // Shared with the audio thread.
    private let lock = NSLock()
    private var detector: NoteDetector?
    private var consumed: Int = 0
    private var expected: Set<Int> = []
    private var guards: [ClosedRange<TimeInterval>] = []
    private var appNotes: Set<Int> = []
    private var mutedUntil: TimeInterval = 0

    // MARK: Starting and stopping

    func start() {
        wanted = true
        guard state != .listening && state != .asking else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            state = .asking
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self, self.state == .asking else { return }
                    if !self.wanted {
                        self.state = .off
                    } else if granted {
                        self.begin()
                    } else {
                        self.state = .denied
                    }
                }
            }
        default:
            state = .denied
        }
    }

    func stop() {
        wanted = false
        let wasListening: Bool = state == .listening
        halt()
        state = .off
        if wasListening {
            sessionHook?(false)
        }
    }

    /// Restarts listening after the system stopped it (app sent to the background, a phone call).
    func resume() {
        guard wanted, state == .listening, !engine.isRunning else { return }
        halt()
        begin()
    }

    private func begin() {
        sessionHook?(true)

        let input: AVAudioInputNode = engine.inputNode
        let format: AVAudioFormat = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            state = .failed("No microphone was found.")
            sessionHook?(false)
            return
        }

        lock.lock()
        detector = NoteDetector(sampleRate: format.sampleRate)
        consumed = 0
        lock.unlock()

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.receive(buffer, at: time)
        }
        tapInstalled = true

        if observer == nil {
            // Plugging in headphones or changing the input device stops the engine.
            observer = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
            ) { [weak self] _ in
                guard let self = self, self.wanted, self.state == .listening else { return }
                self.halt()
                self.begin()
            }
        }

        engine.prepare()
        do {
            try engine.start()
            state = .listening
        } catch {
            halt()
            state = .failed("The microphone could not be started (" + error.localizedDescription + ").")
            sessionHook?(false)
        }
    }

    private func halt() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning {
            engine.stop()
        }
        lock.lock()
        let held: [Int] = (detector?.sounding ?? []).sorted()
        detector = nil
        lock.unlock()
        // Do not leave keys lit.
        for midi in held {
            onNote?(NoteInput(kind: .off, midi: midi, velocity: 0, time: HostClock.now, source: .microphone))
        }
    }

    // MARK: What the app knows

    /// The notes the exercise is waiting for. Knowing them is what makes chords recognisable.
    func setExpected(_ notes: Set<Int>) {
        lock.lock()
        expected = notes
        lock.unlock()
    }

    /// Times at which the app itself makes sound (metronome, accompaniment). The microphone
    /// hears that too, so around those times only expected notes are believed.
    func setGuards(_ ranges: [ClosedRange<TimeInterval>]) {
        lock.lock()
        guards = ranges
        lock.unlock()
    }

    /// The app is playing this note itself (an on-screen key); stop listening while it sounds.
    func appNote(_ midi: Int, on: Bool) {
        lock.lock()
        if on {
            appNotes.insert(midi)
        } else {
            appNotes.remove(midi)
        }
        mutedUntil = max(mutedUntil, HostClock.now + 0.4)
        lock.unlock()
    }

    // MARK: Audio thread

    private func receive(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let channels = buffer.floatChannelData else { return }
        let count: Int = Int(buffer.frameLength)
        let rate: Double = buffer.format.sampleRate
        guard count > 0, rate > 0 else { return }
        let samples: UnsafeMutablePointer<Float> = channels[0]
        let start: TimeInterval = time.isHostTimeValid
            ? HostClock.seconds(fromHostTime: time.hostTime)
            : HostClock.now - Double(count) / rate

        var notes: [NoteInput] = []
        lock.lock()
        if let detector = detector {
            detector.expected = expected
            if let first = guards.first, first.upperBound < start - 1 {
                guards.removeAll { $0.upperBound < start - 1 }
            }
            let base: Int = consumed
            var offset: Int = 0
            // Small pieces, so that the mode can follow the metronome closely.
            while offset < count {
                let length: Int = min(512, count - offset)
                let from: TimeInterval = start + Double(offset) / rate
                let to: TimeInterval = from + Double(length) / rate
                var mode: NoteDetector.Mode = .normal
                if !appNotes.isEmpty || from < mutedUntil {
                    mode = .muted
                } else if guards.contains(where: { $0.lowerBound <= to && $0.upperBound >= from }) {
                    mode = .guarded
                }
                let piece = UnsafeBufferPointer(start: samples + offset, count: length)
                for event in detector.process(piece, mode: mode) {
                    notes.append(NoteInput(
                        kind: event.kind == .on ? .on : .off,
                        midi: event.midi,
                        velocity: event.velocity,
                        time: start + Double(event.position - base) / rate,
                        source: .microphone
                    ))
                }
                offset += length
            }
            consumed += count
        }
        lock.unlock()

        if notes.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.state == .listening else { return }
            for note in notes {
                self.onNote?(note)
            }
        }
    }
}

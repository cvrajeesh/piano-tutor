import Foundation
import AVFoundation
import AudioToolbox

/// Plays piano notes and metronome clicks. macOS ships a General MIDI sound bank; iOS does not,
/// so there the app uses a bank bundled as `SoundBank.sf2` or `SoundBank.dls` if one is present
/// and otherwise the sampler's built-in plain tone.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let piano = AVAudioUnitSampler()
    private let percussion = AVAudioUnitSampler()
    private var started: Bool = false
    private var bankLoaded: Bool = false

    var volume: Double = 0.8 {
        didSet {
            engine.mainMixerNode.outputVolume = Float(volume)
        }
    }

    func start() {
        guard !started else { return }
        started = true

        engine.attach(piano)
        engine.attach(percussion)
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        engine.connect(percussion, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = Float(volume)

        #if os(iOS)
        // Play even when the ring/silent switch is set to silent.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif

        do {
            try engine.start()
        } catch {
            NSLog("Piano Tutor: could not start audio (%@)", error.localizedDescription)
            return
        }

        // If no bank can be loaded the samplers fall back to a plain tone, which still works.
        guard let bank = AudioEngine.soundBankURL() else { return }
        do {
            try piano.loadSoundBankInstrument(
                at: bank,
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            try percussion.loadSoundBankInstrument(
                at: bank,
                program: 0,
                bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            bankLoaded = true
        } catch {
            NSLog("Piano Tutor: could not load the sound bank (%@)", error.localizedDescription)
        }
    }

    private static func soundBankURL() -> URL? {
        for ext in ["sf2", "dls"] {
            if let bundled = Bundle.main.url(forResource: "SoundBank", withExtension: ext) {
                return bundled
            }
        }
        #if os(macOS)
        let system = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        if FileManager.default.fileExists(atPath: system.path) {
            return system
        }
        #endif
        return nil
    }

    /// Restarts the engine after the system stopped it (app sent to the background, a phone call).
    func resume() {
        guard started, !engine.isRunning else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        try? engine.start()
    }

    func noteOn(_ midi: Int, velocity: Int = 90) {
        guard started, midi >= 0, midi <= 127 else { return }
        piano.startNote(UInt8(midi), withVelocity: UInt8(min(max(velocity, 1), 127)), onChannel: 0)
    }

    func noteOff(_ midi: Int) {
        guard started, midi >= 0, midi <= 127 else { return }
        piano.stopNote(UInt8(midi), onChannel: 0)
    }

    /// A wood-block tick; the accented one marks the first beat of a measure.
    func click(accent: Bool) {
        guard started else { return }
        if bankLoaded {
            percussion.startNote(accent ? 76 : 77, withVelocity: accent ? 115 : 85, onChannel: 0)
            return
        }
        // Without a percussion bank the sampler holds a plain tone, so cut it to a short blip.
        let note: UInt8 = accent ? 96 : 91
        percussion.startNote(note, withVelocity: accent ? 115 : 85, onChannel: 0)
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.04) { [percussion] in
            percussion.stopNote(note, onChannel: 0)
        }
    }

    func allNotesOff() {
        guard started else { return }
        for note in 21...108 {
            piano.stopNote(UInt8(note), onChannel: 0)
        }
    }
}

/// Fires closures at precise host-clock times from a high-priority timer,
/// so metronome clicks do not depend on the screen refresh.
final class EventScheduler {
    private struct Item {
        let time: TimeInterval
        let action: () -> Void
    }

    private var items: [Item] = []
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "pianotutor.scheduler", qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    func start() {
        guard timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(3), leeway: .milliseconds(1))
        source.setEventHandler { [weak self] in
            self?.fire()
        }
        source.resume()
        timer = source
    }

    func schedule(_ batch: [(TimeInterval, () -> Void)]) {
        lock.lock()
        for entry in batch {
            items.append(Item(time: entry.0, action: entry.1))
        }
        items.sort { $0.time < $1.time }
        lock.unlock()
    }

    func cancelAll() {
        lock.lock()
        items.removeAll()
        lock.unlock()
    }

    private func fire() {
        let now: TimeInterval = HostClock.now
        var due: [Item] = []
        lock.lock()
        while let first = items.first, first.time <= now {
            due.append(first)
            items.removeFirst()
        }
        lock.unlock()
        for item in due {
            item.action()
        }
    }
}

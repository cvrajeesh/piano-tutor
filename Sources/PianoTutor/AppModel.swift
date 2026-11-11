import SwiftUI
import Combine
import PianoTutorCore

enum SidebarSection: String, CaseIterable, Identifiable {
    case learn
    case songs
    case freePlay
    case settings

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .learn: return String(localized: "Learn", comment: "Section name in the sidebar and tab bar: the course")
        case .songs: return String(localized: "Songs", comment: "Section name in the sidebar and tab bar: the song library")
        case .freePlay: return String(localized: "Free Play", comment: "Section name in the sidebar and tab bar: play anything and see the notes")
        case .settings: return String(localized: "Settings", comment: "Section name in the sidebar and tab bar")
        }
    }

    var symbol: String {
        switch self {
        case .learn: return "graduationcap.fill"
        case .songs: return "music.note.list"
        case .freePlay: return "pianokeys"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Whether the Mac plays the notes you press.
enum MonitorMode: String, CaseIterable, Identifiable {
    /// Silent for a MIDI keyboard (it has its own speakers), sound for on-screen and computer keys.
    case auto
    case always
    case never

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .auto: return String(localized: "Automatic", comment: "Option for hearing your playing through the device: decide automatically")
        case .always: return String(localized: "Always", comment: "Option for hearing your playing through the device")
        case .never: return String(localized: "Never", comment: "Option for hearing your playing through the device")
        }
    }
}

struct ProgressStore: Codable {
    var lessonStars: [String: Int] = [:]
    var songStars: [String: Int] = [:]
}

/// The last note received from each input, shown in Settings to check the connection.
/// Kept out of `AppModel` so that playing a note only refreshes the views that show it.
final class LastNotes: ObservableObject {
    @Published fileprivate(set) var midi: String?
    @Published fileprivate(set) var heard: String?
}

final class AppModel: ObservableObject {
    @Published var section: SidebarSection = .learn
    @Published var activeLesson: Lesson?
    @Published var activeSong: Song?
    @Published private(set) var progress: ProgressStore
    let lastNotes = LastNotes()

    @Published var monitorMode: MonitorMode {
        didSet { defaults.set(monitorMode.rawValue, forKey: Keys.monitorMode) }
    }
    @Published var volume: Double {
        didSet {
            defaults.set(volume, forKey: Keys.volume)
            audio.volume = volume
        }
    }
    /// Positive values forgive notes that register late (Bluetooth audio, slow USB hubs).
    @Published var timingOffsetMs: Double {
        didSet { defaults.set(timingOffsetMs, forKey: Keys.timingOffset) }
    }
    @Published var unlockAll: Bool {
        didSet { defaults.set(unlockAll, forKey: Keys.unlockAll) }
    }
    /// Listen for a piano through the microphone whenever no MIDI keyboard is connected.
    @Published var useMicrophone: Bool {
        didSet {
            defaults.set(useMicrophone, forKey: Keys.useMicrophone)
            updateMicrophone()
        }
    }

    /// For noisy rooms: notes heard by the microphone that are not in the music are passed
    /// over instead of being marked as mistakes.
    @Published var micRightNotesOnly: Bool {
        didSet { defaults.set(micRightNotesOnly, forKey: Keys.micRightNotesOnly) }
    }

    let midi = MIDIManager()
    let mic = MicrophoneInput()
    let audio = AudioEngine()
    let input = InputHub()
    let scheduler = EventScheduler()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var started: Bool = false

    private enum Keys {
        static let progress = "progress.v1"
        static let monitorMode = "monitorMode"
        static let volume = "volume"
        static let timingOffset = "timingOffsetMs"
        static let unlockAll = "unlockAll"
        static let useMicrophone = "useMicrophone"
        static let micRightNotesOnly = "micRightNotesOnly"
    }

    init() {
        let store = UserDefaults.standard
        var loaded = ProgressStore()
        if let data = store.data(forKey: Keys.progress),
           let stored = try? JSONDecoder().decode(ProgressStore.self, from: data) {
            loaded = stored
        }
        let storedVolume: Double = store.object(forKey: Keys.volume) == nil ? 0.8 : store.double(forKey: Keys.volume)
        progress = loaded
        monitorMode = MonitorMode(rawValue: store.string(forKey: Keys.monitorMode) ?? "") ?? .auto
        volume = storedVolume
        timingOffsetMs = store.double(forKey: Keys.timingOffset)
        unlockAll = store.bool(forKey: Keys.unlockAll)
        useMicrophone = store.bool(forKey: Keys.useMicrophone)
        micRightNotesOnly = store.bool(forKey: Keys.micRightNotesOnly)
    }

    /// Starts audio and MIDI. Safe to call more than once.
    func start() {
        guard !started else { return }
        started = true

        audio.volume = volume
        audio.start()
        scheduler.start()

        input.monitor = { [weak self] note in
            self?.playMonitor(note)
        }
        input.installComputerKeyboard()

        midi.onNote = { [weak self] message in
            guard let self = self else { return }
            if message.isOn {
                self.lastNotes.midi = NoteNaming.current.fullName(midi: message.note)
            }
            self.input.send(NoteInput(
                kind: message.isOn ? .on : .off,
                midi: message.note,
                velocity: message.velocity,
                time: message.time,
                source: .midi
            ))
        }
        midi.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        midi.start()

        mic.onNote = { [weak self] note in
            guard let self = self else { return }
            if note.kind == .on {
                self.lastNotes.heard = NoteNaming.current.fullName(midi: note.midi)
            }
            self.input.send(note)
        }
        mic.sessionHook = { [weak self] recording in
            self?.audio.setRecording(recording)
        }
        input.onExpectedNotes = { [weak self] notes in
            self?.mic.setExpected(notes)
        }
        mic.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // The microphone is a stand-in: it steps aside as soon as a MIDI keyboard appears.
        midi.$sourceNames
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMicrophone() }
            .store(in: &cancellables)
        updateMicrophone()
    }

    private func updateMicrophone() {
        guard started else { return }
        if useMicrophone && !midi.isConnected {
            mic.start()
        } else if mic.state != .off {
            mic.stop()
        }
    }

    /// Restarts audio after the system stopped it (app sent to the background, a phone call).
    func resumeAudio() {
        audio.resume()
        mic.resume()
    }

    /// How long after a note is played the app may still learn of it. The microphone needs
    /// a moment to recognise a note; its notes still carry the time they were actually played.
    var inputLag: TimeInterval {
        return mic.isListening ? 0.25 : 0
    }

    private func playMonitor(_ note: NoteInput) {
        // A note heard through the microphone is already sounding in the room.
        if note.source == .microphone { return }
        let audible: Bool
        switch monitorMode {
        case .always: audible = true
        case .never: audible = false
        case .auto: audible = note.source != .midi
        }
        guard audible else { return }
        // The microphone would hear the app's own piano, so it stops listening meanwhile.
        switch note.kind {
        case .on:
            mic.appNote(note.midi, on: true)
            audio.noteOn(note.midi, velocity: note.velocity)
        case .off:
            mic.appNote(note.midi, on: false)
            audio.noteOff(note.midi)
        }
    }

    var timingOffset: TimeInterval {
        return timingOffsetMs / 1000.0
    }

    // MARK: Progress

    func stars(forLesson id: String) -> Int {
        return progress.lessonStars[id] ?? 0
    }

    func stars(forSong id: String) -> Int {
        return progress.songStars[id] ?? 0
    }

    func isUnlocked(_ lesson: Lesson) -> Bool {
        if unlockAll { return true }
        let all: [Lesson] = Curriculum.allLessons
        guard let index = all.firstIndex(where: { $0.id == lesson.id }) else { return true }
        if index == 0 { return true }
        return stars(forLesson: all[index - 1].id) > 0
    }

    /// The first lesson that has not been completed yet.
    var nextLesson: Lesson? {
        return Curriculum.allLessons.first { stars(forLesson: $0.id) == 0 }
    }

    func lesson(after lesson: Lesson) -> Lesson? {
        let all: [Lesson] = Curriculum.allLessons
        guard let index = all.firstIndex(where: { $0.id == lesson.id }), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    func record(lesson id: String, stars: Int) {
        let best: Int = max(progress.lessonStars[id] ?? 0, stars)
        progress.lessonStars[id] = best
        saveProgress()
    }

    func record(song id: String, stars: Int) {
        let best: Int = max(progress.songStars[id] ?? 0, stars)
        progress.songStars[id] = best
        saveProgress()
    }

    func resetProgress() {
        progress = ProgressStore()
        saveProgress()
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: Keys.progress)
        }
    }
}

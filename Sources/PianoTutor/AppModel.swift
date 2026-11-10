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
        case .learn: return "Learn"
        case .songs: return "Songs"
        case .freePlay: return "Free Play"
        case .settings: return "Settings"
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
        case .auto: return "Automatic"
        case .always: return "Always"
        case .never: return "Never"
        }
    }
}

struct ProgressStore: Codable {
    var lessonStars: [String: Int] = [:]
    var songStars: [String: Int] = [:]
}

final class AppModel: ObservableObject {
    @Published var section: SidebarSection = .learn
    @Published var activeLesson: Lesson?
    @Published var activeSong: Song?
    @Published private(set) var progress: ProgressStore
    @Published private(set) var lastMIDINote: String?

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

    let midi = MIDIManager()
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
                self.lastMIDINote = Pitch.fromMIDI(message.note).fullName
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
    }

    private func playMonitor(_ note: NoteInput) {
        let audible: Bool
        switch monitorMode {
        case .always: audible = true
        case .never: audible = false
        case .auto: audible = note.source != .midi
        }
        guard audible else { return }
        switch note.kind {
        case .on: audio.noteOn(note.midi, velocity: note.velocity)
        case .off: audio.noteOff(note.midi)
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

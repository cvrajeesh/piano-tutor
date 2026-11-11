import Foundation

// The titles, summaries and other text in the course and the song library are English
// source text. The app translates each one at display time with its Course string table
// (Sources/PianoTutor/Resources/Course.xcstrings), using the English text as the key, and
// a test checks that every one of them is translated. Changing a string here means
// updating its translations too; see docs/localization.md.

/// What is written on a key that a lesson points out.
public enum KeyLabel: Hashable {
    /// A finger number, 1 (thumb) to 5.
    case finger(Int)
    /// The note's name, written the learner's way (see `NoteNaming`).
    case note(Pitch)
    /// Words, such as "Middle C". This is English source text: the app translates it
    /// with the Course string table, like the rest of the lesson text.
    case text(String)
}

/// A key to point out on the on-screen keyboard.
public struct KeyMark: Hashable {
    public let midi: Int
    public let hand: Hand?
    public let label: KeyLabel?

    public init(midi: Int, hand: Hand? = nil, label: KeyLabel? = nil) {
        self.midi = midi
        self.hand = hand
        self.label = label
    }
}

/// A page of explanation, optionally with highlighted keys and a notation example.
public struct InfoCard {
    public let title: String
    public let paragraphs: [String]
    public let marks: [KeyMark]
    public let figure: Score?
}

public struct FindTarget: Hashable {
    public let midi: Int
    /// When true, the same note name in any octave is accepted.
    public let anyOctave: Bool
    /// The note as spelled in the lesson, so that B♭ is not shown as A♯.
    public let pitch: Pitch
}

/// "Find this key" drill without notation.
public struct FindTask {
    public let title: String
    public let detail: String
    public let targets: [FindTarget]
    public let showHint: Bool
    public let hand: Hand
}

public struct ExerciseSpec {
    public let title: String
    public let instruction: String
    public let score: Score
    public let hands: Set<Hand>
    /// Print letter names inside the note heads.
    public let noteNames: Bool
    /// Light up the next key on the on-screen keyboard.
    public let keyHints: Bool
}

public enum LessonStep {
    case info(InfoCard)
    case find(FindTask)
    /// The music waits for the right notes.
    case practice(ExerciseSpec)
    /// Played in time with the metronome and scored.
    case play(ExerciseSpec)
}

public struct Lesson: Identifiable {
    public let id: String
    public let title: String
    public let summary: String
    public let steps: [LessonStep]
}

public struct CourseUnit: Identifiable {
    public let id: String
    public let title: String
    public let summary: String
    public let lessons: [Lesson]
}

public struct Song: Identifiable {
    public let id: String
    public let title: String
    public let credit: String
    /// 1 = first tunes, 2 = getting going, 3 = a real challenge.
    public let level: Int
    public let score: Score
}

/// Collects problems found while building the built-in material, so a typo in a
/// lesson shows up in the tests instead of crashing the app.
public enum ContentLog {
    public private(set) static var errors: [String] = []

    static func report(_ message: String) {
        errors.append(message)
    }
}

// MARK: - Builders used by the content files

func sc(
    _ right: String? = nil,
    left: String? = nil,
    time: TimeSignature = .common,
    tempo: Double = 72,
    key: Int = 0,
    pickup: Double = 0,
    rp: String? = "C4",
    lp: String? = "C3"
) -> Score {
    do {
        return try Score(
            right: right,
            left: left,
            time: time,
            tempo: tempo,
            key: key,
            pickup: pickup,
            rightPosition: rp,
            leftPosition: lp
        )
    } catch {
        ContentLog.report("\(error) in: \(right ?? "") / \(left ?? "")")
        return Score.empty
    }
}

func midiNumber(_ name: String) -> Int {
    guard let pitch = Pitch(name) else {
        ContentLog.report("Unknown pitch '\(name)'")
        return 60
    }
    return pitch.midi
}

func mark(_ name: String, _ label: KeyLabel? = nil, hand: Hand? = nil) -> KeyMark {
    return KeyMark(midi: midiNumber(name), hand: hand, label: label)
}

/// A key labelled with its own note name.
func named(_ name: String, hand: Hand? = nil) -> KeyMark {
    guard let pitch = Pitch(name) else {
        ContentLog.report("Unknown pitch '\(name)'")
        return KeyMark(midi: 60, hand: hand, label: nil)
    }
    return KeyMark(midi: pitch.midi, hand: hand, label: .note(pitch))
}

func info(_ title: String, _ paragraphs: [String], marks: [KeyMark] = [], figure: Score? = nil) -> LessonStep {
    return .info(InfoCard(title: title, paragraphs: paragraphs, marks: marks, figure: figure))
}

func find(_ title: String, _ detail: String, _ names: [String], anyOctave: Bool = false, hint: Bool = true, hand: Hand = .right) -> LessonStep {
    var targets: [FindTarget] = []
    for name in names {
        guard let pitch = Pitch(name) else {
            ContentLog.report("Unknown pitch '\(name)'")
            continue
        }
        targets.append(FindTarget(midi: pitch.midi, anyOctave: anyOctave, pitch: pitch))
    }
    return .find(FindTask(title: title, detail: detail, targets: targets, showHint: hint, hand: hand))
}

func practice(_ title: String, _ instruction: String, _ score: Score, hands: Set<Hand>? = nil, names: Bool = true, hints: Bool = true) -> LessonStep {
    return .practice(ExerciseSpec(title: title, instruction: instruction, score: score, hands: hands ?? score.hands, noteNames: names, keyHints: hints))
}

func play(_ title: String, _ instruction: String, _ score: Score, hands: Set<Hand>? = nil, names: Bool = true, hints: Bool = true) -> LessonStep {
    return .play(ExerciseSpec(title: title, instruction: instruction, score: score, hands: hands ?? score.hands, noteNames: names, keyHints: hints))
}

extension Lesson {
    /// Every exercise in the lesson, for validation.
    public var exercises: [ExerciseSpec] {
        var result: [ExerciseSpec] = []
        for step in steps {
            switch step {
            case .practice(let spec), .play(let spec):
                result.append(spec)
            case .info, .find:
                break
            }
        }
        return result
    }
}

import Foundation
import PianoTutorCore

// Localization helpers. The app's own text is in Resources/Localizable.xcstrings and is
// looked up through SwiftUI's string literals and `String(localized:)`. The course and the
// song library come from PianoTutorCore as English text, which is translated with the
// Course table (Resources/Course.xcstrings). See docs/localization.md.

extension String {
    /// This English text from the course or the song library, in the app's language.
    /// Falls back to the English text when there is no translation.
    var courseLocalized: String {
        return Bundle.main.localizedString(forKey: self, value: nil, table: "Course")
    }
}

extension NoteNaming {
    /// The name of a key, such as "C♯", "Cis" or "Do♯", spelled with sharps.
    func name(midi: Int) -> String {
        return name(Pitch.fromMIDI(midi))
    }

    /// The name of a key with its octave, such as "C4", "Do4" or "ド4".
    func fullName(midi: Int) -> String {
        return fullName(Pitch.fromMIDI(midi))
    }
}

extension KeyLabel {
    /// The text written on the key.
    var text: String {
        switch self {
        case .finger(let number):
            return String(number)
        case .note(let pitch):
            return NoteNaming.current.name(pitch)
        case .text(let words):
            return words.courseLocalized
        }
    }
}

enum SongLevel {
    /// The heading for the songs of one difficulty level.
    static func name(_ level: Int) -> String {
        switch level {
        case 1: return String(localized: "First tunes", comment: "Song library heading for the easiest songs")
        case 2: return String(localized: "Getting going", comment: "Song library heading for songs of medium difficulty")
        default: return String(localized: "A challenge", comment: "Song library heading for the hardest songs")
        }
    }
}

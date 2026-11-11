import Foundation

/// How note names are written for the learner. Countries name the same keys differently:
/// English and Chinese use letters (C D E), German uses letters with H for B and its own
/// names for sharps and flats (Fis, B), and French, Spanish, Italian, Portuguese, Japanese
/// and Korean use fixed-do solfège (Do Ré Mi, Dó Ré Mi, ドレミ, 도레미).
///
/// The convention follows the app's language, so that the names on the staff and the
/// keyboard match the ones the lesson text uses. Octave numbers always follow scientific
/// pitch notation, with Middle C as 4, whatever the language.
public struct NoteNaming: Hashable {
    public enum Style: Hashable {
        /// C D E F G A B, with ♯ and ♭.
        case letters
        /// C D E F G A H; Cis, Es, B and so on.
        case german
        /// Fixed do, spelled for the language, with ♯ and ♭.
        case solfege
    }

    public let style: Style
    /// The seven syllables or letters, from C to B.
    let syllables: [String]

    public static let english = NoteNaming(style: .letters, syllables: ["C", "D", "E", "F", "G", "A", "B"])
    public static let german = NoteNaming(style: .german, syllables: ["C", "D", "E", "F", "G", "A", "H"])
    public static let french = NoteNaming(style: .solfege, syllables: ["Do", "Ré", "Mi", "Fa", "Sol", "La", "Si"])
    /// Spanish and Italian.
    public static let latin = NoteNaming(style: .solfege, syllables: ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"])
    public static let portuguese = NoteNaming(style: .solfege, syllables: ["Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si"])
    public static let japanese = NoteNaming(style: .solfege, syllables: ["ド", "レ", "ミ", "ファ", "ソ", "ラ", "シ"])
    public static let korean = NoteNaming(style: .solfege, syllables: ["도", "레", "미", "파", "솔", "라", "시"])

    /// The convention for a language code such as "fr", "pt-BR" or "zh-Hans".
    /// Languages without a rule of their own get letter names.
    public init(language: String) {
        let base: String = language.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)?.lowercased() ?? ""
        switch base {
        case "de": self = .german
        case "fr": self = .french
        case "es", "it": self = .latin
        case "pt": self = .portuguese
        case "ja": self = .japanese
        case "ko": self = .korean
        default: self = .english
        }
    }

    init(style: Style, syllables: [String]) {
        self.style = style
        self.syllables = syllables
    }

    /// The convention for the language the app is running in. That is the first of the
    /// user's preferred languages that the app is translated into, not necessarily the
    /// system language. Set once at launch: changing the app's language restarts it.
    public static let current: NoteNaming = {
        return NoteNaming(language: Bundle.main.preferredLocalizations.first ?? "en")
    }()

    /// The name without an octave, such as "F♯", "Fis", "Fa♯" or "ファ♯".
    public func name(_ pitch: Pitch) -> String {
        if style == .german {
            return germanName(pitch)
        }
        return syllables[pitch.letter] + pitch.accidentalSymbol
    }

    /// The name with its octave number, such as "C4", "Do4" or "ド4".
    public func fullName(_ pitch: Pitch) -> String {
        return name(pitch) + String(pitch.octave)
    }

    /// The name of the note without its accidental, as printed inside a note head. The
    /// accidental is drawn on the staff next to it. German B flat is "B", not "H".
    public func headLabel(_ pitch: Pitch) -> String {
        if style == .german && pitch.letter == 6 && pitch.alter == -1 {
            return "B"
        }
        return syllables[pitch.letter]
    }

    /// German adds "is" for a sharp and "es" for a flat, with the irregular Es, As and B.
    private func germanName(_ pitch: Pitch) -> String {
        let letter: String = syllables[pitch.letter]
        switch pitch.alter {
        case 1:
            return letter + "is"
        case -1:
            switch pitch.letter {
            case 2: return "Es"
            case 5: return "As"
            case 6: return "B"
            default: return letter + "es"
            }
        default:
            return letter
        }
    }
}

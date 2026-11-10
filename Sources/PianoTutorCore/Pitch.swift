import Foundation

public enum Hand: String, Codable, CaseIterable, Hashable {
    case right
    case left
}

/// A spelled pitch such as F♯4. Middle C is C4 (MIDI note 60).
public struct Pitch: Hashable, Codable, CustomStringConvertible {
    /// 0 = C, 1 = D … 6 = B
    public let letter: Int
    /// -1 = flat, 0 = natural, +1 = sharp
    public let alter: Int
    public let octave: Int

    static let letterNames: [String] = ["C", "D", "E", "F", "G", "A", "B"]
    static let semitones: [Int] = [0, 2, 4, 5, 7, 9, 11]

    public init(letter: Int, alter: Int = 0, octave: Int) {
        self.letter = letter
        self.alter = alter
        self.octave = octave
    }

    /// Parses text such as "C4", "F#4" or "Bb3".
    public init?(_ text: String) {
        let chars: [Character] = Array(text)
        guard chars.count >= 2 else { return nil }
        let first: String = String(chars[0]).uppercased()
        guard let letterIndex = Pitch.letterNames.firstIndex(of: first) else { return nil }
        var index: Int = 1
        var alteration: Int = 0
        if chars[index] == "#" || chars[index] == "♯" {
            alteration = 1
            index += 1
        } else if chars[index] == "b" || chars[index] == "♭" {
            alteration = -1
            index += 1
        }
        guard index < chars.count, let octaveValue = Int(String(chars[index...])) else { return nil }
        self.letter = letterIndex
        self.alter = alteration
        self.octave = octaveValue
    }

    public var midi: Int {
        return 12 * (octave + 1) + Pitch.semitones[letter] + alter
    }

    /// Counts white-key steps from C0, ignoring accidentals. Used for staff placement.
    public var diatonicIndex: Int {
        return octave * 7 + letter
    }

    public var letterName: String {
        return Pitch.letterNames[letter]
    }

    public var accidentalSymbol: String {
        if alter > 0 { return "♯" }
        if alter < 0 { return "♭" }
        return ""
    }

    /// For example "F♯".
    public var name: String {
        return letterName + accidentalSymbol
    }

    /// For example "F♯4".
    public var fullName: String {
        return name + String(octave)
    }

    public var description: String {
        return fullName
    }

    public static let middleC = Pitch(letter: 0, alter: 0, octave: 4)

    private static let sharpSpelling: [(Int, Int)] = [
        (0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (3, 0),
        (3, 1), (4, 0), (4, 1), (5, 0), (5, 1), (6, 0),
    ]
    private static let flatSpelling: [(Int, Int)] = [
        (0, 0), (1, -1), (1, 0), (2, -1), (2, 0), (3, 0),
        (4, -1), (4, 0), (5, -1), (5, 0), (6, -1), (6, 0),
    ]

    public static func fromMIDI(_ midi: Int, preferFlats: Bool = false) -> Pitch {
        let pitchClass: Int = ((midi % 12) + 12) % 12
        let octaveValue: Int = (midi - pitchClass) / 12 - 1
        let spelling: (Int, Int) = preferFlats ? flatSpelling[pitchClass] : sharpSpelling[pitchClass]
        return Pitch(letter: spelling.0, alter: spelling.1, octave: octaveValue)
    }
}

public enum Clef: Hashable {
    case treble
    case bass

    /// Staff position of a pitch: 0 is the bottom line, 8 the top line, each step is a line or a space.
    public func staffPosition(of pitch: Pitch) -> Int {
        switch self {
        case .treble:
            return pitch.diatonicIndex - 30  // bottom line is E4
        case .bass:
            return pitch.diatonicIndex - 18  // bottom line is G2
        }
    }
}

/// The 61 keys of a standard five-octave keyboard such as the Casio CT-S300 (C2 to C7).
public enum KeyboardRange {
    public static let lowest: Int = 36
    public static let highest: Int = 96

    public static func isBlack(_ midi: Int) -> Bool {
        let pitchClass: Int = ((midi % 12) + 12) % 12
        return pitchClass == 1 || pitchClass == 3 || pitchClass == 6 || pitchClass == 8 || pitchClass == 10
    }
}

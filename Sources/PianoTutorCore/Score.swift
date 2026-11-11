import Foundation

public struct TimeSignature: Hashable {
    public let beats: Int
    public let unit: Int

    public init(_ beats: Int, _ unit: Int) {
        self.beats = beats
        self.unit = unit
    }

    /// Measure length in quarter-note beats.
    public var measureLength: Double {
        return Double(beats) * 4.0 / Double(unit)
    }

    public static let common = TimeSignature(4, 4)
    public static let threeFour = TimeSignature(3, 4)
    public static let twoFour = TimeSignature(2, 4)
}

/// One written note of a (possibly tied) note event.
public struct NoteSegment: Hashable {
    public let start: Double
    public let duration: Double

    public init(start: Double, duration: Double) {
        self.start = start
        self.duration = duration
    }
}

/// A note or chord the player strikes once. Times are in quarter-note beats from the start.
public struct NoteEvent: Identifiable, Hashable {
    public let id: Int
    public let hand: Hand
    public let start: Double
    public let duration: Double
    /// Sorted from lowest to highest.
    public let pitches: [Pitch]
    /// Finger numbers (1 = thumb … 5 = little finger), parallel to `pitches`.
    public let fingers: [Int?]
    /// More than one segment means the note is written as tied notes.
    public let segments: [NoteSegment]

    public init(id: Int, hand: Hand, start: Double, duration: Double, pitches: [Pitch], fingers: [Int?], segments: [NoteSegment]) {
        self.id = id
        self.hand = hand
        self.start = start
        self.duration = duration
        self.pitches = pitches
        self.fingers = fingers
        self.segments = segments
    }

    public var midiNotes: [Int] {
        return pitches.map { $0.midi }
    }
}

public struct RestEvent: Hashable {
    public let hand: Hand
    public let start: Double
    public let duration: Double

    public init(hand: Hand, start: Double, duration: Double) {
        self.hand = hand
        self.start = start
        self.duration = duration
    }
}

public struct Score {
    public let time: TimeSignature
    /// Quarter notes per minute.
    public let tempo: Double
    /// Positive = number of sharps, negative = number of flats.
    public let keySignature: Int
    /// Length in beats of an incomplete first measure, or 0.
    public let pickup: Double
    /// Sorted by start time; `notes[i].id == i`.
    public let notes: [NoteEvent]
    public let rests: [RestEvent]
    public let totalBeats: Double

    public init(time: TimeSignature, tempo: Double, keySignature: Int, pickup: Double, notes: [NoteEvent], rests: [RestEvent], totalBeats: Double) {
        self.time = time
        self.tempo = tempo
        self.keySignature = keySignature
        self.pickup = pickup
        self.notes = notes
        self.rests = rests
        self.totalBeats = totalBeats
    }

    public static let empty = Score(time: .common, tempo: 80, keySignature: 0, pickup: 0, notes: [], rests: [], totalBeats: 0)

    public var isEmpty: Bool {
        return notes.isEmpty
    }

    public var hands: Set<Hand> {
        return Set(notes.map { $0.hand })
    }

    /// Beat positions of the barlines between measures (not including the start or the end).
    public var barlines: [Double] {
        var result: [Double] = []
        let length: Double = time.measureLength
        var beat: Double = pickup > 0 ? pickup : length
        while beat < totalBeats - 1e-6 {
            result.append(beat)
            beat += length
        }
        return result
    }

    public func measureIndex(at beat: Double) -> Int {
        let length: Double = time.measureLength
        if pickup > 0 {
            if beat < pickup - 1e-6 { return 0 }
            return 1 + Int(((beat - pickup) / length + 1e-6).rounded(.down))
        }
        return Int((beat / length + 1e-6).rounded(.down))
    }

    public func measureStart(_ index: Int) -> Double {
        let length: Double = time.measureLength
        if pickup > 0 {
            return index == 0 ? 0 : pickup + Double(index - 1) * length
        }
        return Double(index) * length
    }
}

/// Notes that begin together and must be played together.
public struct NoteGroup: Hashable {
    public let start: Double
    public let eventIDs: [Int]
    public let midiNotes: Set<Int>

    public init(start: Double, eventIDs: [Int], midiNotes: Set<Int>) {
        self.start = start
        self.eventIDs = eventIDs
        self.midiNotes = midiNotes
    }
}

extension Score {
    public func groups(for hands: Set<Hand>) -> [NoteGroup] {
        var result: [NoteGroup] = []
        var currentStart: Double = -1
        var currentIDs: [Int] = []
        var currentNotes: Set<Int> = []
        for note in notes where hands.contains(note.hand) {
            if !currentIDs.isEmpty && abs(note.start - currentStart) > 1e-6 {
                result.append(NoteGroup(start: currentStart, eventIDs: currentIDs, midiNotes: currentNotes))
                currentIDs = []
                currentNotes = []
            }
            if currentIDs.isEmpty {
                currentStart = note.start
            }
            currentIDs.append(note.id)
            for midi in note.midiNotes {
                currentNotes.insert(midi)
            }
        }
        if !currentIDs.isEmpty {
            result.append(NoteGroup(start: currentStart, eventIDs: currentIDs, midiNotes: currentNotes))
        }
        return result
    }
}

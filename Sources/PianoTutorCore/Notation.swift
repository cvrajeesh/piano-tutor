import Foundation

/// A compact text notation for writing lesson material.
///
///     E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4/q. D4/e D4/h
///
/// - A token is `pitches/duration`, e.g. `C4/h`. The duration defaults to a quarter note.
/// - Durations: `w` whole, `h` half, `q` quarter, `e` eighth; add `.` for a dotted note.
/// - Chords join pitches with `+` (`C4+E4+G4/w`); `r` is a rest (`r/h`).
/// - `~` after the duration ties the note to the next one (`G4/w~ | G4/q`).
/// - `:` adds finger numbers (`E4/q:3`, or `C4+E4+G4/w:1-3-5` from the lowest note up).
/// - `|` is a barline; every measure is checked against the time signature.
public struct NotationError: Error, CustomStringConvertible, Equatable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}

struct RawNote {
    var hand: Hand
    var start: Double
    var duration: Double
    var pitches: [Pitch]
    var fingers: [Int?]
    var segments: [NoteSegment]
}

struct ParsedHand {
    var notes: [RawNote] = []
    var rests: [RestEvent] = []
    var length: Double = 0
}

enum NotationParser {
    static let epsilon: Double = 1e-6

    static func parseDuration(_ text: Substring) throws -> Double {
        var body: Substring = text
        var dotted: Bool = false
        if body.hasSuffix(".") {
            dotted = true
            body = body.dropLast()
        }
        var value: Double
        switch String(body) {
        case "w": value = 4
        case "h": value = 2
        case "q": value = 1
        case "e": value = 0.5
        default: throw NotationError("Unknown duration '\(text)'")
        }
        if dotted {
            if value == 4 { throw NotationError("Dotted whole notes are not supported") }
            value *= 1.5
        }
        return value
    }

    static func parseHand(_ text: String, hand: Hand, time: TimeSignature, pickup: Double) throws -> ParsedHand {
        var result = ParsedHand()
        var beat: Double = 0
        var measureIndex: Int = 0
        var measureFill: Double = 0
        var tieOpen: Bool = false
        let fullMeasure: Double = time.measureLength

        func expectedLength(_ index: Int) -> Double {
            return (index == 0 && pickup > 0) ? pickup : fullMeasure
        }

        let tokens: [Substring] = text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
        for token in tokens {
            if token == "|" {
                let expected: Double = expectedLength(measureIndex)
                if abs(measureFill - expected) > epsilon {
                    throw NotationError("Measure \(measureIndex + 1) (\(hand.rawValue) hand) has \(measureFill) beats, expected \(expected)")
                }
                measureIndex += 1
                measureFill = 0
                continue
            }

            let fingerSplit: [Substring] = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let mainText: Substring = fingerSplit[0]
            let fingerText: Substring? = fingerSplit.count > 1 ? fingerSplit[1] : nil

            let durationSplit: [Substring] = mainText.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            let pitchText: Substring = durationSplit[0]
            var durationText: Substring = durationSplit.count > 1 ? durationSplit[1] : Substring("q")
            var tie: Bool = false
            if durationText.hasSuffix("~") {
                tie = true
                durationText = durationText.dropLast()
            }
            let duration: Double = try parseDuration(durationText)

            if pitchText == "r" {
                if tie || tieOpen { throw NotationError("A rest cannot be tied (measure \(measureIndex + 1))") }
                result.rests.append(RestEvent(hand: hand, start: beat, duration: duration))
            } else {
                var pitches: [Pitch] = []
                for part in pitchText.split(separator: "+") {
                    guard let pitch = Pitch(String(part)) else {
                        throw NotationError("Unknown pitch '\(part)' in '\(token)'")
                    }
                    pitches.append(pitch)
                }
                if pitches.isEmpty { throw NotationError("Empty note token '\(token)'") }
                pitches.sort { $0.midi < $1.midi }

                var fingers: [Int?] = Array(repeating: nil, count: pitches.count)
                if let fingerText = fingerText {
                    let parts: [Substring] = fingerText.split(separator: "-")
                    if parts.count != pitches.count {
                        throw NotationError("Finger count does not match notes in '\(token)'")
                    }
                    for (index, part) in parts.enumerated() {
                        guard let finger = Int(String(part)), finger >= 1, finger <= 5 else {
                            throw NotationError("Bad finger number in '\(token)'")
                        }
                        fingers[index] = finger
                    }
                }

                if tieOpen {
                    let last: Int = result.notes.count - 1
                    if last < 0 || result.notes[last].pitches != pitches {
                        throw NotationError("Tied notes must have the same pitch ('\(token)')")
                    }
                    result.notes[last].duration += duration
                    result.notes[last].segments.append(NoteSegment(start: beat, duration: duration))
                } else {
                    result.notes.append(RawNote(
                        hand: hand,
                        start: beat,
                        duration: duration,
                        pitches: pitches,
                        fingers: fingers,
                        segments: [NoteSegment(start: beat, duration: duration)]
                    ))
                }
                tieOpen = tie
            }

            beat += duration
            measureFill += duration
            if measureFill > expectedLength(measureIndex) + epsilon {
                throw NotationError("Measure \(measureIndex + 1) (\(hand.rawValue) hand) is too long")
            }
        }

        if tieOpen { throw NotationError("A tie at the end has nothing to connect to") }
        result.length = beat
        return result
    }

    /// The finger that falls on `pitch` when the hand rests in a five-finger position.
    /// `root` is the lowest note of the position (thumb for the right hand, little finger for the left).
    static func positionFinger(pitch: Pitch, hand: Hand, root: Pitch) -> Int? {
        let offset: Int = pitch.diatonicIndex - root.diatonicIndex
        if offset < 0 || offset > 4 { return nil }
        return hand == .right ? offset + 1 : 5 - offset
    }
}

extension Score {
    /// Builds a score from text notation. See `NotationError` for the format.
    /// - Parameters:
    ///   - rightPosition: lowest note of the right hand's five-finger position, used to fill in finger numbers.
    ///   - leftPosition: lowest note of the left hand's five-finger position.
    public init(
        right: String? = nil,
        left: String? = nil,
        time: TimeSignature = .common,
        tempo: Double = 80,
        key: Int = 0,
        pickup: Double = 0,
        rightPosition: String? = nil,
        leftPosition: String? = nil
    ) throws {
        var raw: [RawNote] = []
        var rests: [RestEvent] = []
        var total: Double = 0

        let sources: [(String?, Hand, String?)] = [(right, .right, rightPosition), (left, .left, leftPosition)]
        for (text, hand, position) in sources {
            guard let text = text else { continue }
            var parsed: ParsedHand = try NotationParser.parseHand(text, hand: hand, time: time, pickup: pickup)
            if let position = position {
                guard let root = Pitch(position) else {
                    throw NotationError("Unknown hand position '\(position)'")
                }
                for noteIndex in parsed.notes.indices {
                    for pitchIndex in parsed.notes[noteIndex].pitches.indices where parsed.notes[noteIndex].fingers[pitchIndex] == nil {
                        let pitch: Pitch = parsed.notes[noteIndex].pitches[pitchIndex]
                        parsed.notes[noteIndex].fingers[pitchIndex] = NotationParser.positionFinger(pitch: pitch, hand: hand, root: root)
                    }
                }
            }
            raw.append(contentsOf: parsed.notes)
            rests.append(contentsOf: parsed.rests)
            total = max(total, parsed.length)
        }

        raw.sort { a, b in
            if abs(a.start - b.start) > NotationParser.epsilon { return a.start < b.start }
            return a.hand == .right && b.hand == .left
        }

        var notes: [NoteEvent] = []
        for (index, note) in raw.enumerated() {
            notes.append(NoteEvent(
                id: index,
                hand: note.hand,
                start: note.start,
                duration: note.duration,
                pitches: note.pitches,
                fingers: note.fingers,
                segments: note.segments
            ))
        }

        self.init(time: time, tempo: tempo, keySignature: key, pickup: pickup, notes: notes, rests: rests, totalBeats: total)
    }
}

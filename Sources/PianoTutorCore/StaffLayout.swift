import Foundation

public enum NoteValue: Hashable {
    case whole
    case half
    case quarter
    case eighth
}

public struct NoteShape: Hashable {
    public let value: NoteValue
    public let dotted: Bool

    public init(value: NoteValue, dotted: Bool) {
        self.value = value
        self.dotted = dotted
    }

    /// The written shape for a duration in quarter-note beats.
    public init(duration: Double) {
        if duration >= 3.99 {
            self.init(value: .whole, dotted: false)
        } else if duration >= 2.99 {
            self.init(value: .half, dotted: true)
        } else if duration >= 1.99 {
            self.init(value: .half, dotted: false)
        } else if duration >= 1.49 {
            self.init(value: .quarter, dotted: true)
        } else if duration >= 0.99 {
            self.init(value: .quarter, dotted: false)
        } else if duration >= 0.74 {
            self.init(value: .eighth, dotted: true)
        } else {
            self.init(value: .eighth, dotted: false)
        }
    }
}

public struct LaidHead: Hashable {
    public let pitch: Pitch
    /// Staff position: 0 = bottom line, 8 = top line.
    public let position: Int
    /// The accidental to print, if any: -1 flat, 0 natural, +1 sharp.
    public let accidental: Int?
}

/// One written note (or chord) on the staff.
public struct LaidNote: Hashable {
    public let index: Int
    public let eventID: Int
    public let segmentIndex: Int
    public let hand: Hand
    public let clef: Clef
    public let start: Double
    public let duration: Double
    public let shape: NoteShape
    /// Lowest to highest.
    public let heads: [LaidHead]
    public var stemUp: Bool
    public var beamGroup: Int?
    /// True when this note is tied into the next written note of the same event.
    public let tieToNext: Bool
}

public struct LaidRest: Hashable {
    public let hand: Hand
    public let clef: Clef
    public let start: Double
    public let duration: Double
    public let shape: NoteShape
    public let fillsMeasure: Bool
}

public struct BeamGroup: Hashable {
    public let noteIndices: [Int]
    public let stemUp: Bool
}

/// Everything needed to draw a score that does not depend on pixel sizes:
/// staff positions, accidentals, stem directions and beams.
public struct StaffLayout {
    public let score: Score
    /// The staves to draw, top to bottom.
    public let clefs: [Clef]
    public private(set) var notes: [LaidNote]
    public let rests: [LaidRest]
    public private(set) var beams: [BeamGroup]

    public static func clef(for hand: Hand) -> Clef {
        return hand == .right ? .treble : .bass
    }

    /// Alteration applied to each letter (0 = C … 6 = B) by a key signature.
    public static func keyAlterations(_ keySignature: Int) -> [Int] {
        var result: [Int] = Array(repeating: 0, count: 7)
        let sharpOrder: [Int] = [3, 0, 4, 1, 5, 2, 6]  // F C G D A E B
        let flatOrder: [Int] = [6, 2, 5, 1, 4, 0, 3]   // B E A D G C F
        if keySignature > 0 {
            for i in 0..<min(keySignature, 7) { result[sharpOrder[i]] = 1 }
        } else if keySignature < 0 {
            for i in 0..<min(-keySignature, 7) { result[flatOrder[i]] = -1 }
        }
        return result
    }

    /// Staff positions of key-signature accidentals, in the order they are written.
    public static func keySignaturePositions(_ keySignature: Int, clef: Clef) -> [Int] {
        let sharps: [Int] = [8, 5, 9, 6, 3, 7, 4]
        let flats: [Int] = [4, 7, 3, 6, 2, 5, 1]
        let source: [Int] = keySignature >= 0 ? sharps : flats
        let count: Int = min(abs(keySignature), 7)
        let shift: Int = clef == .bass ? -2 : 0
        return source.prefix(count).map { $0 + shift }
    }

    public init(score: Score, staves: [Clef]? = nil) {
        self.score = score
        if let staves = staves {
            self.clefs = staves
        } else {
            let hands: Set<Hand> = score.hands
            if hands.contains(.right) && hands.contains(.left) {
                self.clefs = [.treble, .bass]
            } else if hands.contains(.left) {
                self.clefs = [.bass]
            } else {
                self.clefs = [.treble]
            }
        }

        let keyAlter: [Int] = StaffLayout.keyAlterations(score.keySignature)
        var laid: [LaidNote] = []

        for hand in Hand.allCases {
            let clef: Clef = StaffLayout.clef(for: hand)
            var currentMeasure: Int = -1
            // Accidentals already in force in this measure, keyed by diatonic index.
            var measureState: [Int: Int] = [:]

            for event in score.notes where event.hand == hand {
                for (segmentIndex, segment) in event.segments.enumerated() {
                    let measure: Int = score.measureIndex(at: segment.start)
                    if measure != currentMeasure {
                        currentMeasure = measure
                        measureState = [:]
                    }
                    var heads: [LaidHead] = []
                    for pitch in event.pitches {
                        let inForce: Int = measureState[pitch.diatonicIndex] ?? keyAlter[pitch.letter]
                        var accidental: Int? = nil
                        if segmentIndex == 0 && pitch.alter != inForce {
                            accidental = pitch.alter
                        }
                        measureState[pitch.diatonicIndex] = pitch.alter
                        heads.append(LaidHead(pitch: pitch, position: clef.staffPosition(of: pitch), accidental: accidental))
                    }
                    var positionSum: Int = 0
                    for head in heads { positionSum += head.position }
                    let average: Double = Double(positionSum) / Double(max(heads.count, 1))
                    laid.append(LaidNote(
                        index: laid.count,
                        eventID: event.id,
                        segmentIndex: segmentIndex,
                        hand: hand,
                        clef: clef,
                        start: segment.start,
                        duration: segment.duration,
                        shape: NoteShape(duration: segment.duration),
                        heads: heads,
                        stemUp: average < 4,
                        beamGroup: nil,
                        tieToNext: segmentIndex < event.segments.count - 1
                    ))
                }
            }
        }

        // Beam pairs of eighth notes that share a beat.
        var beamGroups: [BeamGroup] = []
        for hand in Hand.allCases {
            let indices: [Int] = laid.indices.filter { laid[$0].hand == hand }
            var cursor: Int = 0
            while cursor + 1 < indices.count {
                let first: LaidNote = laid[indices[cursor]]
                let second: LaidNote = laid[indices[cursor + 1]]
                let bothEighths: Bool = first.shape == NoteShape(value: .eighth, dotted: false)
                    && second.shape == NoteShape(value: .eighth, dotted: false)
                let onBeat: Bool = abs(first.start - first.start.rounded()) < 1e-6
                let adjacent: Bool = abs(second.start - (first.start + 0.5)) < 1e-6
                if bothEighths && onBeat && adjacent {
                    var sum: Int = 0
                    var count: Int = 0
                    for head in first.heads + second.heads {
                        sum += head.position
                        count += 1
                    }
                    let up: Bool = Double(sum) / Double(max(count, 1)) < 4
                    let groupIndex: Int = beamGroups.count
                    beamGroups.append(BeamGroup(noteIndices: [first.index, second.index], stemUp: up))
                    laid[first.index].stemUp = up
                    laid[first.index].beamGroup = groupIndex
                    laid[second.index].stemUp = up
                    laid[second.index].beamGroup = groupIndex
                    cursor += 2
                } else {
                    cursor += 1
                }
            }
        }

        var laidRests: [LaidRest] = []
        for rest in score.rests {
            let fills: Bool = abs(rest.duration - score.time.measureLength) < 1e-6
            laidRests.append(LaidRest(
                hand: rest.hand,
                clef: StaffLayout.clef(for: rest.hand),
                start: rest.start,
                duration: rest.duration,
                shape: NoteShape(duration: rest.duration),
                fillsMeasure: fills
            ))
        }

        self.notes = laid
        self.rests = laidRests
        self.beams = beamGroups
    }
}

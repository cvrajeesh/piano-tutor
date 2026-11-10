import Foundation

// MARK: - Practice mode: the music waits for the player

/// Steps through a score one note group at a time and waits for the right keys.
public final class StepTrainer {
    public enum Response: Equatable {
        /// A correct key of a chord that is not complete yet.
        case partial
        /// The group was completed; the trainer moved to the next one.
        case advanced
        /// The last group was completed.
        case finished
        case wrong
        case ignored
    }

    public let groups: [NoteGroup]
    public private(set) var index: Int = 0
    public private(set) var mistakes: Int = 0
    private var held: Set<Int> = []

    public init(score: Score, hands: Set<Hand>) {
        self.groups = score.groups(for: hands)
    }

    public var current: NoteGroup? {
        return index < groups.count ? groups[index] : nil
    }

    public var isFinished: Bool {
        return index >= groups.count
    }

    public func noteOn(_ midi: Int) -> Response {
        guard let group = current else { return .ignored }
        guard group.midiNotes.contains(midi) else {
            mistakes += 1
            return .wrong
        }
        held.insert(midi)
        if group.midiNotes.isSubset(of: held) {
            index += 1
            held.removeAll()
            return isFinished ? .finished : .advanced
        }
        return .partial
    }

    public func noteOff(_ midi: Int) {
        held.remove(midi)
    }

    public var summary: PerformanceSummary {
        return PerformanceSummary(total: groups.count, perfect: index, early: 0, late: 0, missed: 0, strays: mistakes, timed: false)
    }
}

// MARK: - Performance mode: play in time

public enum Grade: Hashable {
    case perfect
    case early
    case late
}

public enum TargetState: Hashable {
    case pending
    case hit(Grade)
    case missed
}

public struct JudgeWindows {
    /// Notes within this many seconds of the beat count as perfect.
    public var perfect: Double = 0.09
    /// Notes further away than this are not matched at all.
    public var hit: Double = 0.24

    public init() {}
}

public struct PerformanceSummary: Equatable {
    public let total: Int
    public let perfect: Int
    public let early: Int
    public let late: Int
    public let missed: Int
    /// Wrong or extra notes.
    public let strays: Int
    /// False for practice mode, where timing is not judged.
    public let timed: Bool

    public init(total: Int, perfect: Int, early: Int, late: Int, missed: Int, strays: Int, timed: Bool) {
        self.total = total
        self.perfect = perfect
        self.early = early
        self.late = late
        self.missed = missed
        self.strays = strays
        self.timed = timed
    }

    public var hits: Int {
        return perfect + early + late
    }

    public var accuracy: Double {
        if total == 0 { return 1 }
        if timed {
            let earned: Double = Double(perfect) + 0.8 * Double(early + late)
            return earned / (Double(total) + 0.25 * Double(strays))
        }
        return Double(total) / Double(total + strays)
    }

    public var stars: Int {
        let value: Double = accuracy
        if timed {
            if value >= 0.9 { return 3 }
            if value >= 0.75 { return 2 }
            if value >= 0.55 { return 1 }
            return 0
        }
        if value >= 0.9 { return 3 }
        if value >= 0.7 { return 2 }
        return 1
    }

    public var passed: Bool {
        return stars >= 1
    }
}

/// Matches incoming notes against the score while the music plays in tempo.
/// Times are seconds measured from beat 0 of the score.
public final class PerformanceJudge {
    public struct Target {
        public let eventID: Int
        public let midi: Int
        public let time: Double
        public var state: TargetState
    }

    public enum Outcome: Equatable {
        case hit(eventID: Int, grade: Grade, offset: Double)
        case stray
    }

    public private(set) var targets: [Target] = []
    public private(set) var strays: Int = 0
    private let windows: JudgeWindows
    private var firstPending: Int = 0
    private var targetsByEvent: [Int: [Int]] = [:]

    public init(score: Score, hands: Set<Hand>, secondsPerBeat: Double, windows: JudgeWindows = JudgeWindows()) {
        self.windows = windows
        var list: [Target] = []
        for note in score.notes where hands.contains(note.hand) {
            for midi in note.midiNotes {
                list.append(Target(eventID: note.id, midi: midi, time: note.start * secondsPerBeat, state: .pending))
            }
        }
        list.sort { $0.time < $1.time }
        self.targets = list
        for (index, target) in list.enumerated() {
            targetsByEvent[target.eventID, default: []].append(index)
        }
    }

    public func noteOn(_ midi: Int, at time: Double) -> Outcome {
        var best: Int? = nil
        var bestDistance: Double = Double.greatestFiniteMagnitude
        var index: Int = firstPending
        while index < targets.count {
            let target: Target = targets[index]
            if target.time - time > windows.hit { break }
            if target.state == .pending && target.midi == midi {
                let distance: Double = abs(target.time - time)
                if distance <= windows.hit && distance < bestDistance {
                    best = index
                    bestDistance = distance
                }
            }
            index += 1
        }
        guard let match = best else {
            strays += 1
            return .stray
        }
        let offset: Double = time - targets[match].time
        let grade: Grade
        if abs(offset) <= windows.perfect {
            grade = .perfect
        } else if offset < 0 {
            grade = .early
        } else {
            grade = .late
        }
        targets[match].state = .hit(grade)
        return .hit(eventID: targets[match].eventID, grade: grade, offset: offset)
    }

    /// Marks notes whose window has passed as missed. Returns the affected event ids.
    public func advance(to time: Double) -> [Int] {
        var missedEvents: [Int] = []
        var index: Int = firstPending
        while index < targets.count {
            if targets[index].time + windows.hit >= time { break }
            if targets[index].state == .pending {
                targets[index].state = .missed
                if !missedEvents.contains(targets[index].eventID) {
                    missedEvents.append(targets[index].eventID)
                }
            }
            index += 1
        }
        firstPending = index
        return missedEvents
    }

    /// The combined state of all notes of an event (a chord counts as hit once every note is hit).
    public func state(ofEvent id: Int) -> TargetState {
        guard let indices = targetsByEvent[id] else { return .pending }
        var worst: Grade = .perfect
        var allHit: Bool = true
        for index in indices {
            switch targets[index].state {
            case .missed:
                return .missed
            case .pending:
                allHit = false
            case .hit(let grade):
                if grade != .perfect { worst = grade }
            }
        }
        return allHit ? .hit(worst) : .pending
    }

    public var summary: PerformanceSummary {
        var perfect: Int = 0
        var early: Int = 0
        var late: Int = 0
        var missed: Int = 0
        for target in targets {
            switch target.state {
            case .hit(.perfect): perfect += 1
            case .hit(.early): early += 1
            case .hit(.late): late += 1
            case .missed, .pending: missed += 1
            }
        }
        return PerformanceSummary(total: targets.count, perfect: perfect, early: early, late: late, missed: missed, strays: strays, timed: true)
    }
}

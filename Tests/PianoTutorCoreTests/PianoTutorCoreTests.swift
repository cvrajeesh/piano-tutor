import XCTest
@testable import PianoTutorCore

final class PitchTests: XCTestCase {
    func testParsingAndMIDINumbers() {
        XCTAssertEqual(Pitch("C4")?.midi, 60)
        XCTAssertEqual(Pitch("F#4")?.midi, 66)
        XCTAssertEqual(Pitch("Bb3")?.midi, 58)
        XCTAssertEqual(Pitch("B3")?.midi, 59)
        XCTAssertEqual(Pitch("C2")?.midi, KeyboardRange.lowest)
        XCTAssertEqual(Pitch("C7")?.midi, KeyboardRange.highest)
        XCTAssertNil(Pitch("H4"))
        XCTAssertNil(Pitch("C"))
    }

    func testNames() {
        XCTAssertEqual(Pitch("F#4")?.name, "F♯")
        XCTAssertEqual(Pitch("Bb3")?.fullName, "B♭3")
        XCTAssertEqual(Pitch.fromMIDI(60).fullName, "C4")
        XCTAssertEqual(Pitch.fromMIDI(61).name, "C♯")
        XCTAssertEqual(Pitch.fromMIDI(61, preferFlats: true).name, "D♭")
    }

    func testStaffPositions() {
        XCTAssertEqual(Clef.treble.staffPosition(of: Pitch("E4")!), 0)
        XCTAssertEqual(Clef.treble.staffPosition(of: Pitch("C4")!), -2)
        XCTAssertEqual(Clef.treble.staffPosition(of: Pitch("F5")!), 8)
        XCTAssertEqual(Clef.bass.staffPosition(of: Pitch("G2")!), 0)
        XCTAssertEqual(Clef.bass.staffPosition(of: Pitch("C4")!), 10)
    }

    func testBlackKeys() {
        XCTAssertTrue(KeyboardRange.isBlack(61))
        XCTAssertTrue(KeyboardRange.isBlack(70))
        XCTAssertFalse(KeyboardRange.isBlack(60))
        XCTAssertFalse(KeyboardRange.isBlack(65))
    }
}

final class NotationTests: XCTestCase {
    func testSimpleMelody() throws {
        let score = try Score(right: "C4 D4 E4/h | C4/w")
        XCTAssertEqual(score.notes.count, 4)
        XCTAssertEqual(score.totalBeats, 8)
        XCTAssertEqual(score.notes[2].start, 2)
        XCTAssertEqual(score.notes[2].duration, 2)
        XCTAssertEqual(score.barlines, [4])
        XCTAssertEqual(score.hands, [.right])
    }

    func testMeasureLengthIsChecked() {
        XCTAssertThrowsError(try Score(right: "C4 D4 E4 | C4/w"))
        XCTAssertThrowsError(try Score(right: "C4 D4 E4 F4 G4 | C4/w"))
        XCTAssertThrowsError(try Score(right: "C4/x"))
        XCTAssertThrowsError(try Score(right: "X4"))
    }

    func testPickupMeasure() throws {
        let score = try Score(right: "C4 | D4 E4 F4 | G4/h", time: .threeFour, pickup: 1)
        XCTAssertEqual(score.barlines, [1, 4])
        XCTAssertEqual(score.measureIndex(at: 0), 0)
        XCTAssertEqual(score.measureIndex(at: 1), 1)
        XCTAssertEqual(score.measureIndex(at: 4), 2)
    }

    func testTiesMergeIntoOneEvent() throws {
        let score = try Score(right: "G4/w~ | G4/q C4 E4 F4")
        XCTAssertEqual(score.notes.count, 4)
        XCTAssertEqual(score.notes[0].duration, 5)
        XCTAssertEqual(score.notes[0].segments.count, 2)
        XCTAssertThrowsError(try Score(right: "G4/w~ | A4/q C4 E4 F4"))
        XCTAssertThrowsError(try Score(right: "G4/w~"))
    }

    func testChordsAndFingers() throws {
        let score = try Score(left: "G3+C3+E3/w:5-3-1")
        XCTAssertEqual(score.notes[0].midiNotes, [48, 52, 55])
        XCTAssertEqual(score.notes[0].fingers, [5, 3, 1])
        XCTAssertThrowsError(try Score(left: "C3+E3+G3/w:5-3"))
    }

    func testPositionFingering() throws {
        let score = try Score(right: "C4 E4 G4 A4", left: "C3 E3 G3 B2", rightPosition: "C4", leftPosition: "C3")
        let right = score.notes.filter { $0.hand == .right }
        let left = score.notes.filter { $0.hand == .left }
        XCTAssertEqual(right.map { $0.fingers[0] }, [1, 3, 5, nil])
        XCTAssertEqual(left.map { $0.fingers[0] }, [5, 3, 1, nil])
    }

    func testGroupsCombineHands() throws {
        let score = try Score(right: "C4 D4 E4/h", left: "C3/w")
        let both = score.groups(for: [.right, .left])
        XCTAssertEqual(both.count, 3)
        XCTAssertEqual(both[0].midiNotes, [48, 60])
        XCTAssertEqual(score.groups(for: [.left]).count, 1)
    }
}

final class LayoutTests: XCTestCase {
    func testAccidentalsLastForTheMeasure() throws {
        let score = try Score(right: "F#4 F#4 F4 F4 | F#4/w")
        let layout = StaffLayout(score: score)
        let shown = layout.notes.map { $0.heads[0].accidental }
        XCTAssertEqual(shown, [1, nil, 0, nil, 1])
    }

    func testKeySignatureHidesAccidentals() throws {
        let score = try Score(right: "F#4 G4 F4 F#4", key: 1)
        let layout = StaffLayout(score: score)
        let shown = layout.notes.map { $0.heads[0].accidental }
        XCTAssertEqual(shown, [nil, nil, 0, 1])
    }

    func testEighthNotesAreBeamedInPairs() throws {
        let score = try Score(right: "C4/e D4/e E4 F4/e G4/e A4")
        let layout = StaffLayout(score: score)
        XCTAssertEqual(layout.beams.count, 2)
        XCTAssertEqual(layout.notes[0].beamGroup, 0)
        XCTAssertEqual(layout.notes[1].beamGroup, 0)
        XCTAssertNil(layout.notes[2].beamGroup)
    }

    func testStavesFollowHands() throws {
        XCTAssertEqual(StaffLayout(score: try Score(right: "C4/w")).clefs, [.treble])
        XCTAssertEqual(StaffLayout(score: try Score(left: "C3/w")).clefs, [.bass])
        XCTAssertEqual(StaffLayout(score: try Score(right: "C4/w", left: "C3/w")).clefs, [.treble, .bass])
    }

    func testStemDirection() throws {
        let layout = StaffLayout(score: try Score(right: "C4 C5 B4 A4"))
        XCTAssertEqual(layout.notes.map { $0.stemUp }, [true, false, false, true])
    }
}

final class EngineTests: XCTestCase {
    func testStepTrainerWaitsForRightNotes() throws {
        let score = try Score(right: "C4 D4 C4+E4/h")
        let trainer = StepTrainer(score: score, hands: [.right])
        XCTAssertEqual(trainer.noteOn(62), .wrong)
        XCTAssertEqual(trainer.noteOn(60), .advanced)
        XCTAssertEqual(trainer.noteOn(62), .advanced)
        XCTAssertEqual(trainer.noteOn(60), .partial)
        XCTAssertEqual(trainer.noteOn(64), .finished)
        XCTAssertTrue(trainer.isFinished)
        XCTAssertEqual(trainer.mistakes, 1)
        XCTAssertEqual(trainer.noteOn(60), .ignored)
    }

    func testChordNeedsAllKeysHeldTogether() throws {
        let score = try Score(right: "C4+E4/h C4/h")
        let trainer = StepTrainer(score: score, hands: [.right])
        XCTAssertEqual(trainer.noteOn(60), .partial)
        trainer.noteOff(60)
        XCTAssertEqual(trainer.noteOn(64), .partial)
        XCTAssertEqual(trainer.noteOn(60), .advanced)
    }

    func testJudgeGradesTiming() throws {
        let score = try Score(right: "C4 D4 E4 F4")
        let judge = PerformanceJudge(score: score, hands: [.right], secondsPerBeat: 1)
        XCTAssertEqual(judge.noteOn(60, at: 0.02), .hit(eventID: 0, grade: .perfect, offset: 0.02))
        if case .hit(_, let grade, _) = judge.noteOn(62, at: 0.85) {
            XCTAssertEqual(grade, .early)
        } else {
            XCTFail("Expected an early hit")
        }
        if case .hit(_, let grade, _) = judge.noteOn(64, at: 2.2) {
            XCTAssertEqual(grade, .late)
        } else {
            XCTFail("Expected a late hit")
        }
        XCTAssertEqual(judge.noteOn(61, at: 2.5), .stray)
        XCTAssertEqual(judge.advance(to: 5), [3])
        XCTAssertEqual(judge.state(ofEvent: 3), .missed)

        let summary = judge.summary
        XCTAssertEqual(summary.total, 4)
        XCTAssertEqual(summary.perfect, 1)
        XCTAssertEqual(summary.early, 1)
        XCTAssertEqual(summary.late, 1)
        XCTAssertEqual(summary.missed, 1)
        XCTAssertEqual(summary.strays, 1)
    }

    func testJudgeIgnoresNotesFarFromTheBeat() throws {
        let score = try Score(right: "C4 C4")
        let judge = PerformanceJudge(score: score, hands: [.right], secondsPerBeat: 1)
        XCTAssertEqual(judge.noteOn(60, at: 0.5), .stray)
        if case .hit(let eventID, let grade, let offset) = judge.noteOn(60, at: 0.9) {
            XCTAssertEqual(eventID, 1)
            XCTAssertEqual(grade, .early)
            XCTAssertEqual(offset, -0.1, accuracy: 0.0001)
        } else {
            XCTFail("Expected the second note to be matched")
        }
    }

    func testStars() {
        let perfect = PerformanceSummary(total: 10, perfect: 10, early: 0, late: 0, missed: 0, strays: 0, timed: true)
        XCTAssertEqual(perfect.stars, 3)
        let shaky = PerformanceSummary(total: 10, perfect: 4, early: 2, late: 1, missed: 3, strays: 2, timed: true)
        XCTAssertEqual(shaky.stars, 1)
        let poor = PerformanceSummary(total: 10, perfect: 2, early: 1, late: 0, missed: 7, strays: 0, timed: true)
        XCTAssertEqual(poor.stars, 0)
        XCTAssertFalse(poor.passed)
        let practice = PerformanceSummary(total: 10, perfect: 10, early: 0, late: 0, missed: 0, strays: 1, timed: false)
        XCTAssertEqual(practice.stars, 3)
    }
}

final class ContentTests: XCTestCase {
    func testCourseLoadsWithoutErrors() {
        let lessons = Curriculum.allLessons
        XCTAssertEqual(Curriculum.units.count, 8)
        XCTAssertGreaterThan(lessons.count, 20)
        XCTAssertEqual(Set(lessons.map { $0.id }).count, lessons.count, "Lesson ids must be unique")

        for lesson in lessons {
            XCTAssertFalse(lesson.steps.isEmpty, lesson.id)
            for exercise in lesson.exercises {
                XCTAssertFalse(exercise.score.isEmpty, "\(lesson.id): \(exercise.title)")
                XCTAssertFalse(exercise.score.groups(for: exercise.hands).isEmpty, "\(lesson.id): \(exercise.title)")
                for note in exercise.score.notes {
                    for midi in note.midiNotes {
                        XCTAssertTrue((KeyboardRange.lowest...KeyboardRange.highest).contains(midi), "\(lesson.id): \(exercise.title)")
                    }
                }
            }
        }
        XCTAssertEqual(ContentLog.errors, [])
    }

    func testSongsLoadWithoutErrors() {
        let songs = SongLibrary.songs
        XCTAssertGreaterThan(songs.count, 12)
        XCTAssertEqual(Set(songs.map { $0.id }).count, songs.count, "Song ids must be unique")
        for song in songs {
            XCTAssertFalse(song.score.isEmpty, song.id)
            XCTAssertTrue((1...3).contains(song.level), song.id)
        }
        XCTAssertEqual(ContentLog.errors, [])
    }
}

final class NoteDetectorTests: XCTestCase {
    private let sampleRate: Double = 44100

    private struct Strike {
        let time: Double
        let notes: [Int]
        var length: Double = 0.4
    }

    /// A rough piano: a handful of partials that start at once, fade (the high ones faster)
    /// and are cut off when the key is released, over a little background noise.
    private func audio(_ strikes: [Strike], seconds: Double) -> [Float] {
        var samples = [Float](repeating: 0, count: Int(seconds * sampleRate))
        var seed: UInt64 = 42
        for index in 0..<samples.count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            samples[index] = (Float(seed >> 40) / Float(1 << 24) - 0.5) * 0.002
        }
        for strike in strikes {
            for note in strike.notes {
                let pitch: Double = 440 * pow(2, Double(note - 69) / 12)
                let first: Int = Int(strike.time * sampleRate)
                let count: Int = min(Int((strike.length + 0.3) * sampleRate), samples.count - first)
                for partial in 1...8 {
                    let frequency: Double = pitch * Double(partial) * (1 + 0.0002 * Double(partial * partial))
                    if frequency > 0.45 * sampleRate { break }
                    let strength: Double = 0.12 / pow(Double(partial), 1.3)
                    let fade: Double = 1.5 + 0.8 * Double(partial)
                    for index in 0..<count {
                        let t: Double = Double(index) / sampleRate
                        var envelope: Double = min(t / 0.004, 1) * exp(-fade * t)
                        if t > strike.length {
                            envelope *= exp(-(t - strike.length) / 0.03)
                        }
                        samples[first + index] += Float(strength * envelope * sin(2 * Double.pi * frequency * t))
                    }
                }
            }
        }
        return samples
    }

    private struct Heard: Equatable {
        let midi: Int
        let time: Double
    }

    /// Feeds the audio in small pieces, as the microphone does, and collects the note-ons.
    private func listen(
        _ samples: [Float],
        expected: Set<Int> = [],
        mode: NoteDetector.Mode = .normal
    ) -> [Heard] {
        let detector = NoteDetector(sampleRate: sampleRate)
        detector.expected = expected
        var heard: [Heard] = []
        var offset: Int = 0
        while offset < samples.count {
            let end: Int = min(offset + 441, samples.count)
            for event in detector.process(Array(samples[offset..<end]), mode: mode) where event.kind == .on {
                heard.append(Heard(midi: event.midi, time: Double(event.position) / sampleRate))
            }
            offset = end
        }
        return heard
    }

    func testSingleNotesAcrossTheKeyboard() {
        let keys: [Int] = Array(stride(from: KeyboardRange.lowest, through: KeyboardRange.highest, by: 5))
        let strikes: [Strike] = keys.enumerated().map { Strike(time: 0.3 + Double($0.offset) * 0.6, notes: [$0.element]) }
        let heard = listen(audio(strikes, seconds: 0.6 * Double(keys.count) + 0.6))
        XCTAssertEqual(heard.map { $0.midi }, keys)
        // The reported time is when the key went down, not when it was recognised.
        for (strike, note) in zip(strikes, heard) {
            XCTAssertEqual(note.time, strike.time, accuracy: 0.04)
        }
    }

    func testRepeatedNoteIsHeardEachTime() {
        let strikes: [Strike] = (0..<4).map { Strike(time: 0.3 + Double($0) * 0.5, notes: [67]) }
        let heard = listen(audio(strikes, seconds: 2.6))
        XCTAssertEqual(heard.map { $0.midi }, [67, 67, 67, 67])
    }

    func testHeldNoteIsHeardOnce() {
        let heard = listen(audio([Strike(time: 0.3, notes: [60], length: 3)], seconds: 4))
        XCTAssertEqual(heard.map { $0.midi }, [60])
    }

    func testNoteEndsWhenTheSoundDoes() {
        let detector = NoteDetector(sampleRate: sampleRate)
        var kinds: [NoteDetector.Event.Kind] = []
        for event in detector.process(audio([Strike(time: 0.3, notes: [60])], seconds: 1.5)) {
            kinds.append(event.kind)
        }
        XCTAssertEqual(kinds, [.on, .off])
        XCTAssertTrue(detector.sounding.isEmpty)
    }

    func testSilenceAndNoiseAreNotNotes() {
        XCTAssertEqual(listen(audio([], seconds: 2)), [])
    }

    func testExpectedChordIsRecognised() {
        let samples = audio([Strike(time: 0.5, notes: [60, 64, 67], length: 1)], seconds: 2)
        XCTAssertEqual(listen(samples, expected: [60, 64, 67]).map { $0.midi }, [60, 64, 67])
    }

    func testMissingChordNoteIsNotReported() {
        let samples = audio([Strike(time: 0.5, notes: [60, 67], length: 1)], seconds: 2)
        XCTAssertEqual(listen(samples, expected: [60, 64, 67]).map { $0.midi }, [60, 67])
    }

    func testWrongKeyInsteadOfChord() {
        let samples = audio([Strike(time: 0.5, notes: [62], length: 1)], seconds: 2)
        XCTAssertEqual(listen(samples, expected: [60, 64, 67]).map { $0.midi }, [62])
    }

    func testLowerOctaveIsNotMistakenForTheChordAboveIt() {
        // C3 contains the pitches of C4 and G4 as partials.
        let samples = audio([Strike(time: 0.5, notes: [48], length: 1)], seconds: 2)
        XCTAssertEqual(listen(samples, expected: [60, 67]).map { $0.midi }, [48])
    }

    func testGuardedAndMutedModes() {
        let samples = audio([Strike(time: 0.4, notes: [62]), Strike(time: 1.0, notes: [60])], seconds: 1.8)
        XCTAssertEqual(listen(samples, expected: [60]).map { $0.midi }, [62, 60])
        XCTAssertEqual(listen(samples, expected: [60], mode: .guarded).map { $0.midi }, [60])
        XCTAssertEqual(listen(samples, expected: [60], mode: .muted), [])
    }

    func testOtherSampleRates() {
        for rate in [16000.0, 48000.0] {
            let detector = NoteDetector(sampleRate: rate)
            var samples = [Float](repeating: 0, count: Int(rate))
            for index in Int(0.3 * rate)..<samples.count {
                let t: Double = Double(index) / rate - 0.3
                samples[index] = Float(0.1 * exp(-2 * t) * (sin(2 * Double.pi * 440 * t) + 0.5 * sin(2 * Double.pi * 880 * t)))
            }
            let notes: [Int] = detector.process(samples).filter { $0.kind == .on }.map { $0.midi }
            XCTAssertEqual(notes, [69], "at \(rate) Hz")
        }
    }
}

extension NoteDetectorTests {
    /// Something like a voice: a pitch that slides and wavers, and swells instead of being struck.
    private func voice(from start: Double, pitch: Double, seconds: Double, into samples: inout [Float]) {
        var phase: Double = 0
        let first: Int = Int(start * sampleRate)
        for index in 0..<Int(seconds * sampleRate) where first + index < samples.count {
            let t: Double = Double(index) / sampleRate
            let frequency: Double = pitch * (1 + 0.03 * sin(2 * Double.pi * 5 * t) + 0.1 * t)
            phase += 2 * Double.pi * frequency / sampleRate
            let envelope: Double = min(t / 0.12, 1) * min((seconds - t) / 0.05, 1)
            let wave: Double = sin(phase) + 0.6 * sin(2 * phase) + 0.4 * sin(3 * phase) + 0.3 * sin(4 * phase)
            samples[first + index] += Float(0.08 * envelope * wave)
        }
    }

    func testVoicesAreNotNotes() {
        var samples = audio([], seconds: 5)
        for (index, pitch) in [180.0, 240, 300, 520, 1400, 1900].enumerated() {
            voice(from: 0.3 + Double(index) * 0.75, pitch: pitch, seconds: 0.5, into: &samples)
        }
        XCTAssertEqual(listen(samples, expected: [64]), [])
        XCTAssertEqual(listen(samples), [])
    }

    func testExpectedNoteIsHeardOverAVoice() {
        var samples = audio([Strike(time: 0.6, notes: [64], length: 0.6)], seconds: 2)
        voice(from: 0.3, pitch: 1400, seconds: 1.2, into: &samples)
        XCTAssertEqual(listen(samples, expected: [64]).map { $0.midi }, [64])
    }

    func testRingingNoteIsNotHeardAgainWhenSomethingElseMakesANoise() {
        // E is expected twice running; while the first is still ringing, a voice starts up.
        var samples = audio([Strike(time: 0.4, notes: [64], length: 2)], seconds: 2.4)
        voice(from: 1.0, pitch: 500, seconds: 0.6, into: &samples)
        XCTAssertEqual(listen(samples, expected: [64]).map { $0.midi }, [64])
    }
}

final class LenientJudgeTests: XCTestCase {
    func testDoubtfulNotesAreNotCountedAsMistakes() throws {
        let score = try Score(right: "C4 D4")
        let judge = PerformanceJudge(score: score, hands: [.right], secondsPerBeat: 1)
        XCTAssertEqual(judge.noteOn(77, at: 0.5, countStray: false), .stray)
        XCTAssertEqual(judge.strays, 0)
        XCTAssertEqual(judge.noteOn(77, at: 0.5), .stray)
        XCTAssertEqual(judge.strays, 1)
        // A doubtful note that does match still counts as played.
        XCTAssertEqual(judge.noteOn(60, at: 0, countStray: false), .hit(eventID: 0, grade: .perfect, offset: 0))
    }
}

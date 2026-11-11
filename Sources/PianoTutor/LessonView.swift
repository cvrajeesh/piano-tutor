import SwiftUI
import PianoTutorCore

/// Walks through the steps of one lesson.
struct LessonView: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson

    @State private var stepIndex: Int = 0
    @State private var stepStars: [Int: Int] = [:]
    @State private var finished: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            SessionTopBar(
                title: lesson.title.courseLocalized,
                stepCount: lesson.steps.count,
                stepIndex: finished ? lesson.steps.count : stepIndex,
                onClose: { model.activeLesson = nil }
            )
            if finished || stepIndex >= lesson.steps.count {
                LessonCompleteView(
                    lesson: lesson,
                    stars: lessonStars,
                    next: model.lesson(after: lesson),
                    onDone: { model.activeLesson = nil },
                    onNext: { next in model.activeLesson = next }
                )
            } else {
                stepView(lesson.steps[stepIndex])
                    .id(stepIndex)
            }
        }
    }

    @ViewBuilder
    private func stepView(_ step: LessonStep) -> some View {
        switch step {
        case .info(let card):
            InfoStepView(card: card, onContinue: advance)
        case .find(let task):
            FindStepView(task: task, onDone: advance)
        case .practice(let spec):
            ExerciseView(
                title: spec.title.courseLocalized,
                instruction: spec.instruction.courseLocalized,
                baseConfig: config(for: spec, mode: .wait),
                onContinue: { summary in complete(summary) }
            )
        case .play(let spec):
            ExerciseView(
                title: spec.title.courseLocalized,
                instruction: spec.instruction.courseLocalized,
                baseConfig: config(for: spec, mode: .tempo),
                onContinue: { summary in complete(summary) }
            )
        }
    }

    private func config(for spec: ExerciseSpec, mode: SessionConfig.Mode) -> SessionConfig {
        return SessionConfig(
            score: spec.score,
            mode: mode,
            hands: spec.hands,
            tempoScale: 1.0,
            metronome: true,
            noteNames: spec.noteNames,
            keyHints: spec.keyHints
        )
    }

    private func complete(_ summary: PerformanceSummary) {
        stepStars[stepIndex] = max(stepStars[stepIndex] ?? 0, summary.stars)
        advance()
    }

    private func advance() {
        if stepIndex + 1 < lesson.steps.count {
            stepIndex += 1
        } else {
            finished = true
            model.record(lesson: lesson.id, stars: lessonStars)
        }
    }

    /// The average of the exercise results, and never less than one star for finishing.
    private var lessonStars: Int {
        if stepStars.isEmpty { return 3 }
        var total: Int = 0
        for value in stepStars.values {
            total += value
        }
        let average: Double = Double(total) / Double(stepStars.count)
        return min(max(Int(average.rounded()), 1), 3)
    }
}

/// A page of explanation with an optional notation example.
struct InfoStepView: View {
    @Environment(\.screenLayout) private var screen
    let card: InfoCard
    let onContinue: () -> Void

    @State private var figureSource = StaticStaffSource(beat: -0.7)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(card.title.courseLocalized)
                        .scaledFont(screen.compact ? 22 : 26, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    ForEach(Array(card.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph.courseLocalized)
                            .scaledFont(16)
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let figure = card.figure {
                        let layout = StaffLayout(score: figure)
                        StaffView(
                            layout: layout,
                            source: figureSource,
                            showNoteNames: true,
                            showPlayhead: false,
                            animated: false
                        )
                        .frame(height: (layout.clefs.count > 1 ? 300 : 190) * (screen.compact ? 0.8 : 1))
                        .background(Theme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button("Continue", action: onContinue)
                        .buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .padding(.top, 6)
                }
                .padding(screen.compact ? 18 : 36)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            KeyboardPanel(marks: card.marks)
        }
    }
}

/// "Find this key" drill.
struct FindStepView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var input: InputHub
    @Environment(\.screenLayout) private var screen
    let task: FindTask
    let onDone: () -> Void

    @State private var index: Int = 0
    @State private var found: [Int] = []
    @State private var wrong: Set<Int> = []
    @State private var good: Set<Int> = []
    @State private var message: String = ""
    @State private var done: Bool = false
    /// Grows the target boxes with the text size, so that the names inside still fit.
    @ScaledMetric(relativeTo: .title3) private var boxScale: CGFloat = 1

    private var current: FindTarget? {
        return index < task.targets.count ? task.targets[index] : nil
    }

    private var hintTargets: [Int: KeyTarget] {
        guard task.showHint, let target = current, !target.anyOctave else { return [:] }
        return [target.midi: KeyTarget(hand: task.hand, finger: nil)]
    }

    /// The whole drill's range, so that a cut-down keyboard does not jump about (or give the answer away).
    private var focus: ClosedRange<Int>? {
        let keys: [Int] = task.targets.map { $0.midi }
        guard let low = keys.min(), let high = keys.max() else { return nil }
        return low...high
    }

    /// The side of one target box; they shrink to fit a narrow screen.
    private var boxSize: CGFloat {
        return (screen.compact ? 38 : 54) * boxScale
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: screen.short ? 6 : 18) {
                Spacer(minLength: 0)
                Text(task.title.courseLocalized)
                    .scaledFont(screen.short ? 20 : (screen.narrow ? 24 : 28), weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(task.detail.courseLocalized)
                    .scaledFont(screen.short ? 14 : 16)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: screen.compact ? 6 : 10) {
                    ForEach(Array(task.targets.enumerated()), id: \.offset) { position, target in
                        Text(NoteNaming.current.name(target.pitch))
                            .scaledFont(screen.compact ? 15 : 20, weight: .bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 3)
                            .foregroundStyle(position < index ? Theme.ink : Theme.textPrimary)
                            .frame(width: boxSize, height: boxSize)
                            .background(position < index ? Theme.good : (position == index ? Theme.panelRaised : Theme.panel))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(position == index && !done ? Theme.accent : Color.clear, lineWidth: 2)
                            )
                    }
                }
                .padding(.top, screen.short ? 2 : 8)

                Text(message)
                    .scaledFont(14, weight: .medium)
                    .foregroundStyle(done ? Theme.good : Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minHeight: 20)
                Spacer(minLength: 0)
            }
            .padding(screen.short ? 8 : (screen.narrow ? 16 : 30))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            KeyboardPanel(targets: hintTargets, good: good, wrong: wrong, focus: focus)
        }
        .playingScreenTextLimit()
        .onReceive(input.events) { note in
            handle(note)
        }
        .task(id: done) {
            // A short pause on "That's it!" before moving on. Cancelled if the lesson is closed meanwhile.
            guard done else { return }
            do {
                try await Task.sleep(nanoseconds: 900_000_000)
            } catch {
                return
            }
            onDone()
        }
    }

    private func handle(_ note: NoteInput) {
        if note.kind == .off {
            wrong.remove(note.midi)
            good.remove(note.midi)
            return
        }
        guard !done, let target = current else { return }

        let matches: Bool
        if target.anyOctave {
            matches = (note.midi - target.midi) % 12 == 0
        } else {
            matches = note.midi == target.midi
        }

        if matches && target.anyOctave && found.contains(note.midi) {
            say(String(localized: "You already found that one. Try a different \(NoteNaming.current.name(target.pitch)).", comment: "The placeholder is a note name, such as C"))
            return
        }

        if matches {
            good.insert(note.midi)
            found.append(note.midi)
            index += 1
            if index >= task.targets.count {
                done = true
                say(String(localized: "That's it!", comment: "Shown when every key in a find-the-key drill has been found"))
            } else {
                message = ""
                // Nothing changes on screen but the boxes, so VoiceOver users hear the next target.
                let next: String = NoteNaming.current.name(task.targets[index].pitch)
                Announcer.announce(String(localized: "Right. Next, \(next).", comment: "Read out by VoiceOver after a key is found; the placeholder is the next note to find, such as D"))
            }
        } else if note.source == .microphone && model.micRightNotesOnly {
            return
        } else {
            wrong.insert(note.midi)
            let played: String = NoteNaming.current.name(midi: note.midi)
            let wanted: String = NoteNaming.current.name(target.pitch)
            say(String(localized: "That was \(played). Look for \(wanted).", comment: "Both placeholders are note names, such as C and D: the key that was played and the one to find"))
        }
    }

    /// Shows the message under the targets and reads it out with VoiceOver.
    private func say(_ text: String) {
        message = text
        Announcer.announce(text)
    }
}

struct LessonCompleteView: View {
    @Environment(\.screenLayout) private var screen
    let lesson: Lesson
    let stars: Int
    let next: Lesson?
    let onDone: () -> Void
    let onNext: (Lesson) -> Void

    var body: some View {
        VStack(spacing: screen.short ? 10 : 18) {
            Spacer()
            StarsView(stars: stars, size: screen.short ? 32 : 44)
            Text("Lesson complete")
                .scaledFont(screen.short ? 24 : 30, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            Text(lesson.title.courseLocalized)
                .scaledFont(16)
                .foregroundStyle(Theme.textSecondary)
            // Side by side where there is room, stacked on an upright iPhone.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    buttons
                }
                VStack(spacing: 10) {
                    buttons
                }
            }
            .padding(.top, screen.short ? 2 : 10)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var buttons: some View {
        Button("Back to lessons", action: onDone)
            .buttonStyle(SecondaryButtonStyle())
            .fixedSize()
        if let next = next {
            Button(String(localized: "Next: \(next.title.courseLocalized)", comment: "Button that opens the next lesson; the placeholder is its title")) {
                onNext(next)
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .lineLimit(1)
        }
    }
}

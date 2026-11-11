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
                title: lesson.title,
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
                title: spec.title,
                instruction: spec.instruction,
                baseConfig: config(for: spec, mode: .wait),
                onContinue: { summary in complete(summary) }
            )
        case .play(let spec):
            ExerciseView(
                title: spec.title,
                instruction: spec.instruction,
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
    let card: InfoCard
    let onContinue: () -> Void

    @State private var figureSource = StaticStaffSource(beat: -0.7)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(card.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    ForEach(Array(card.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
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
                        .frame(height: layout.clefs.count > 1 ? 300 : 190)
                        .background(Theme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button("Continue", action: onContinue)
                        .buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .padding(.top, 6)
                }
                .padding(36)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            KeyboardPanel(marks: card.marks)
        }
    }
}

/// "Find this key" drill.
struct FindStepView: View {
    @EnvironmentObject var input: InputHub
    let task: FindTask
    let onDone: () -> Void

    @State private var index: Int = 0
    @State private var found: [Int] = []
    @State private var wrong: Set<Int> = []
    @State private var good: Set<Int> = []
    @State private var message: String = ""
    @State private var done: Bool = false

    private var current: FindTarget? {
        return index < task.targets.count ? task.targets[index] : nil
    }

    private var hintTargets: [Int: KeyTarget] {
        guard task.showHint, let target = current, !target.anyOctave else { return [:] }
        return [target.midi: KeyTarget(hand: task.hand, finger: nil)]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Spacer()
                Text(task.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(task.detail)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    ForEach(Array(task.targets.enumerated()), id: \.offset) { position, target in
                        Text(target.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(position < index ? Theme.ink : Theme.textPrimary)
                            .frame(width: 54, height: 54)
                            .background(position < index ? Theme.good : (position == index ? Theme.panelRaised : Theme.panel))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(position == index && !done ? Theme.accent : Color.clear, lineWidth: 2)
                            )
                    }
                }
                .padding(.top, 8)

                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(done ? Theme.good : Theme.accent)
                    .frame(height: 20)
                Spacer()
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            KeyboardPanel(targets: hintTargets, good: good, wrong: wrong)
        }
        .onReceive(input.events) { note in
            handle(note)
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
            message = "You already found that one. Try a different " + target.name + "."
            return
        }

        if matches {
            good.insert(note.midi)
            found.append(note.midi)
            index += 1
            message = ""
            if index >= task.targets.count {
                done = true
                message = "That's it!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    onDone()
                }
            }
        } else {
            wrong.insert(note.midi)
            let played: String = Pitch.fromMIDI(note.midi).name
            message = "That was " + played + ". Look for " + target.name + "."
        }
    }
}

struct LessonCompleteView: View {
    let lesson: Lesson
    let stars: Int
    let next: Lesson?
    let onDone: () -> Void
    let onNext: (Lesson) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            StarsView(stars: stars, size: 44)
            Text("Lesson complete")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(lesson.title)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 12) {
                Button("Back to lessons", action: onDone)
                    .buttonStyle(SecondaryButtonStyle())
                if let next = next {
                    Button("Next: " + next.title) {
                        onNext(next)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.top, 10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

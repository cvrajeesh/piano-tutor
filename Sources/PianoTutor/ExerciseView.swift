import SwiftUI
import PianoTutorCore

/// One playable exercise: header, scrolling staff, result card and keyboard.
/// Used by lessons and by the song library.
struct ExerciseView: View {
    @EnvironmentObject var model: AppModel
    let title: String
    let instruction: String
    let baseConfig: SessionConfig
    var continueLabel: String = "Continue"
    let onContinue: (PerformanceSummary) -> Void

    @State private var attempt: Int = 0
    @State private var slow: Bool = false

    private var config: SessionConfig {
        var copy: SessionConfig = baseConfig
        if slow {
            copy.tempoScale = baseConfig.tempoScale * 0.75
        }
        return copy
    }

    var body: some View {
        ExercisePlayer(
            config: config,
            model: model,
            title: title,
            instruction: instruction,
            isSlow: slow,
            continueLabel: continueLabel,
            onRetry: { attempt += 1 },
            onToggleSlow: {
                slow.toggle()
                attempt += 1
            },
            onContinue: onContinue
        )
        .id(String(attempt) + (slow ? "-slow" : "-full"))
    }
}

struct ExercisePlayer: View {
    @StateObject private var session: PlaySession
    @Environment(\.screenLayout) private var screen
    let title: String
    let instruction: String
    let isSlow: Bool
    let continueLabel: String
    let onRetry: () -> Void
    let onToggleSlow: () -> Void
    let onContinue: (PerformanceSummary) -> Void

    init(
        config: SessionConfig,
        model: AppModel,
        title: String,
        instruction: String,
        isSlow: Bool,
        continueLabel: String,
        onRetry: @escaping () -> Void,
        onToggleSlow: @escaping () -> Void,
        onContinue: @escaping (PerformanceSummary) -> Void
    ) {
        _session = StateObject(wrappedValue: PlaySession(config: config, model: model))
        self.title = title
        self.instruction = instruction
        self.isSlow = isSlow
        self.continueLabel = continueLabel
        self.onRetry = onRetry
        self.onToggleSlow = onToggleSlow
        self.onContinue = onContinue
    }

    private var isTempo: Bool {
        return session.config.mode == .tempo
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                StaffView(
                    layout: session.layout,
                    source: session,
                    showNoteNames: session.config.noteNames,
                    showPlayhead: true,
                    animated: session.phase != .finished
                )
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if session.phase == .idle && isTempo {
                    startCard
                }
                if session.phase == .finished, let summary = session.result {
                    ResultCard(
                        summary: summary,
                        isSlow: isSlow,
                        continueLabel: continueLabel,
                        onRetry: onRetry,
                        onToggleSlow: onToggleSlow,
                        onContinue: { onContinue(summary) }
                    )
                }
            }
            .padding(.horizontal, screen.compact ? 10 : 20)
            .padding(.bottom, screen.compact ? 8 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            KeyboardPanel(
                targets: session.targets,
                good: session.goodKeys,
                wrong: session.wrongKeys,
                focus: session.config.score.keyRange(hands: session.config.hands)
            )
        }
        .onAppear {
            if !isTempo {
                session.start()
            }
        }
        .onDisappear {
            session.stop()
        }
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: screen.compact ? 17 : 20, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(isTempo ? "IN TIME" : "PRACTICE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isTempo ? Theme.accent : Theme.textSecondary)
                .clipShape(Capsule())
                .fixedSize()
            if isSlow {
                Text("SLOW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.panelRaised)
                    .clipShape(Capsule())
                    .fixedSize()
            }
        }
    }

    private var instructionText: some View {
        Text(instruction)
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(Theme.textSecondary)
    }

    @ViewBuilder
    private var streakLabel: some View {
        if session.streak >= 3 {
            Label(String(session.streak) + " in a row", systemImage: "flame.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.accent)
                .fixedSize()
        }
    }

    private var progressBar: some View {
        ProgressView(value: session.progress)
            .progressViewStyle(.linear)
            .tint(Theme.accent)
    }

    @ViewBuilder
    private var restartButton: some View {
        if session.phase == .running {
            Button("Restart", action: onRetry)
                .buttonStyle(SecondaryButtonStyle(small: screen.compact))
        }
    }

    @ViewBuilder
    private var header: some View {
        if screen.narrow {
            // Upright iPhone: stack everything.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    titleRow
                    Spacer(minLength: 0)
                    streakLabel
                    restartButton
                }
                .frame(minHeight: 32)
                instructionText
                    .fixedSize(horizontal: false, vertical: true)
                progressBar
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else if screen.short {
            // iPhone on its side: one line, to leave the height to the staff.
            HStack(alignment: .center, spacing: 12) {
                titleRow
                    .layoutPriority(1)
                instructionText
                    .lineLimit(1)
                Spacer(minLength: 0)
                streakLabel
                progressBar
                    .frame(width: 80)
                restartButton
            }
            .frame(minHeight: 32)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        } else {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    titleRow
                    instructionText
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                streakLabel
                progressBar
                    .frame(width: 140)
                restartButton
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    private var startCard: some View {
        VStack(spacing: screen.short ? 8 : 12) {
            Text("Ready?")
                .font(.system(size: screen.short ? 18 : 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text("You will hear one measure of clicks before the first note.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Start") {
                session.start()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(screen.short ? 14 : 26)
        .background(Theme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.35), radius: 18, y: 6)
    }
}

/// Shown when an exercise ends.
struct ResultCard: View {
    @Environment(\.screenLayout) private var screen
    let summary: PerformanceSummary
    let isSlow: Bool
    let continueLabel: String
    let onRetry: () -> Void
    let onToggleSlow: () -> Void
    let onContinue: () -> Void

    private var headline: String {
        if !summary.passed { return "Nearly there" }
        switch summary.stars {
        case 3: return "Beautifully played"
        case 2: return "Well done"
        default: return "You got through it"
        }
    }

    private var detail: String {
        let percent: Int = Int((summary.accuracy * 100).rounded())
        if summary.timed {
            var text: String = String(summary.hits) + " of " + String(summary.total) + " notes, "
                + String(summary.perfect) + " right on the beat"
            if summary.strays > 0 {
                text += ", " + String(summary.strays) + " wrong"
            }
            return text + " (" + String(percent) + "%)"
        }
        if summary.strays == 0 { return "Every note right first time." }
        return String(summary.strays) + (summary.strays == 1 ? " wrong key" : " wrong keys") + " along the way."
    }

    var body: some View {
        VStack(spacing: screen.short ? 6 : 14) {
            StarsView(stars: summary.stars, size: screen.short ? 20 : 30)
            Text(headline)
                .font(.system(size: screen.short ? 18 : 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(detail)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if !summary.passed && !screen.short {
                Text("Try it again, or slow the tempo down first.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: screen.compact ? 8 : 10) {
                Button("Try again", action: onRetry)
                    .buttonStyle(SecondaryButtonStyle(small: screen.compact))
                if summary.timed {
                    Button(isSlow ? "Full speed" : "Slower", action: onToggleSlow)
                        .buttonStyle(SecondaryButtonStyle(small: screen.compact))
                }
                if summary.passed {
                    Button(continueLabel, action: onContinue)
                        .buttonStyle(PrimaryButtonStyle(small: screen.compact))
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Skip", action: onContinue)
                        .buttonStyle(SecondaryButtonStyle(small: screen.compact))
                }
            }
            .fixedSize()
            .padding(.top, 4)
        }
        .padding(screen.compact ? 16 : 28)
        .background(Theme.panel.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 8)
    }
}

/// The bar across the top of a lesson or song, with a close button.
/// `accessory` is extra content placed in the bar (the song options on an iPhone held sideways).
struct SessionTopBar<Accessory: View>: View {
    @Environment(\.screenLayout) private var screen
    let title: String
    let stepCount: Int
    let stepIndex: Int
    let onClose: () -> Void
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: screen.compact ? 10 : 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(Theme.panelRaised)
                    .clipShape(Circle())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close")

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)

            if stepCount > 1 {
                HStack(spacing: screen.narrow ? 2 : 4) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        Capsule()
                            .fill(index < stepIndex ? Theme.accent : (index == stepIndex ? Theme.textPrimary : Color(white: 0.3)))
                            .frame(height: 5)
                    }
                }
                .frame(minWidth: 60, maxWidth: 420)
            }
            accessory()
            Spacer(minLength: 0)
            ConnectionBadge(dotOnly: screen.compact)
        }
        .padding(.horizontal, screen.compact ? 12 : 20)
        .padding(.vertical, screen.short ? 6 : 10)
        .background(Theme.panel)
    }
}

extension SessionTopBar where Accessory == EmptyView {
    init(title: String, stepCount: Int, stepIndex: Int, onClose: @escaping () -> Void) {
        self.init(title: title, stepCount: stepCount, stepIndex: stepIndex, onClose: onClose, accessory: { EmptyView() })
    }
}

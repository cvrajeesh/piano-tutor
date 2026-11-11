import SwiftUI
import PianoTutorCore

/// One playable exercise: header, scrolling staff, result card and keyboard.
/// Used by lessons and by the song library.
struct ExerciseView: View {
    @EnvironmentObject var model: AppModel
    let title: String
    let instruction: String
    let baseConfig: SessionConfig
    var continueLabel: String = String(localized: "Continue")
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
        // Created once per view identity: later changes to `config` are ignored here.
        // `ExerciseView` and `SongSessionView` change this view's `.id` to start a new session instead.
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
        .playingScreenTextLimit()
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
                .scaledFont(screen.compact ? 17 : 20, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            modeBadge
                .textCase(.uppercase)
                .scaledFont(10, weight: .bold)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isTempo ? Theme.accent : Theme.textSecondary)
                .clipShape(Capsule())
                .fixedSize()
            if isSlow {
                Text("Slow", comment: "Badge on an exercise played at a slower tempo, shown in capitals")
                    .textCase(.uppercase)
                    .scaledFont(10, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.panelRaised)
                    .clipShape(Capsule())
                    .fixedSize()
            }
        }
    }

    private var modeBadge: Text {
        if isTempo {
            return Text("In time", comment: "Badge for the mode where you play along with the metronome, shown in capitals")
        }
        return Text("Practice", comment: "Badge for the mode where the music waits for you, shown in capitals")
    }

    private var instructionText: some View {
        Text(instruction)
            .scaledFont(13)
            .foregroundStyle(Theme.textSecondary)
    }

    @ViewBuilder
    private var streakLabel: some View {
        if session.streak >= 3 {
            Label {
                Text("\(session.streak) in a row", comment: "How many notes in a row were right, such as 5 in a row")
            } icon: {
                Image(systemName: "flame.fill")
            }
                .scaledFont(13, weight: .semibold)
                .foregroundStyle(Theme.accent)
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
                .scaledFont(screen.short ? 18 : 22, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            Text("You will hear one measure of clicks before the first note.")
                .scaledFont(13)
                .foregroundStyle(Theme.textSecondary)
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
        if !summary.passed { return String(localized: "Nearly there", comment: "Result headline for an exercise that was not passed") }
        switch summary.stars {
        case 3: return String(localized: "Beautifully played", comment: "Result headline for three stars")
        case 2: return String(localized: "Well done", comment: "Result headline for two stars")
        default: return String(localized: "You got through it", comment: "Result headline for one star")
        }
    }

    private var detail: String {
        if summary.timed {
            let percent: String = summary.accuracy.formatted(.percent.precision(.fractionLength(0)))
            if summary.strays > 0 {
                return String(localized: "\(summary.hits) of \(summary.total) notes, \(summary.perfect) right on the beat, \(summary.strays) wrong (\(percent))", comment: "Result of an exercise played in time. The last placeholder is the accuracy as a percentage, such as 85%")
            }
            return String(localized: "\(summary.hits) of \(summary.total) notes, \(summary.perfect) right on the beat (\(percent))", comment: "Result of an exercise played in time. The last placeholder is the accuracy as a percentage, such as 85%")
        }
        if summary.strays == 0 { return String(localized: "Every note right first time.") }
        return String(localized: "\(summary.strays) wrong keys along the way.", comment: "Result of a practice exercise: how many wrong keys were pressed")
    }

    var body: some View {
        VStack(spacing: screen.short ? 6 : 14) {
            StarsView(stars: summary.stars, size: screen.short ? 20 : 30)
            Text(headline)
                .scaledFont(screen.short ? 18 : 24, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            Text(detail)
                .scaledFont(13)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if !summary.passed && !screen.short {
                Text("Try it again, or slow the tempo down first.")
                    .scaledFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: screen.compact ? 8 : 10) {
                Button("Try again", action: onRetry)
                    .buttonStyle(SecondaryButtonStyle(small: screen.compact))
                if summary.timed {
                    Button(action: onToggleSlow) {
                        if isSlow {
                            Text("Full speed", comment: "Button that plays the exercise again at its normal tempo")
                        } else {
                            Text("Slower", comment: "Button that plays the exercise again at a slower tempo")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(small: screen.compact))
                }
                if summary.passed {
                    Button(continueLabel, action: onContinue)
                        .buttonStyle(PrimaryButtonStyle(small: screen.compact))
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(action: onContinue) {
                        Text("Skip", comment: "Button that moves on without passing the exercise")
                    }
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
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(Theme.panelRaised)
                    .clipShape(Circle())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close")

            Text(title)
                .scaledFont(14, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
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

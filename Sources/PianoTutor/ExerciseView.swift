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
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            KeyboardPanel(targets: session.targets, good: session.goodKeys, wrong: session.wrongKeys)
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

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text(isTempo ? "IN TIME" : "PRACTICE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isTempo ? Theme.accent : Theme.textSecondary)
                        .clipShape(Capsule())
                    if isSlow {
                        Text("SLOW")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.panelRaised)
                            .clipShape(Capsule())
                    }
                }
                Text(instruction)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if session.streak >= 3 {
                Label(String(session.streak) + " in a row", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.accent)
            }
            ProgressView(value: session.progress)
                .progressViewStyle(.linear)
                .tint(Theme.accent)
                .frame(width: 140)
            if session.phase == .running {
                Button("Restart", action: onRetry)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var startCard: some View {
        VStack(spacing: 12) {
            Text("Ready?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text("You will hear one measure of clicks before the first note.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Theme.textSecondary)
            Button("Start") {
                session.start()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(26)
        .background(Theme.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.35), radius: 18, y: 6)
    }
}

/// Shown when an exercise ends.
struct ResultCard: View {
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
        VStack(spacing: 14) {
            StarsView(stars: summary.stars, size: 30)
            Text(headline)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(detail)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Theme.textSecondary)
            if !summary.passed {
                Text("Try it again, or slow the tempo down first.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                Button("Try again", action: onRetry)
                    .buttonStyle(SecondaryButtonStyle())
                if summary.timed {
                    Button(isSlow ? "Full speed" : "Slower", action: onToggleSlow)
                        .buttonStyle(SecondaryButtonStyle())
                }
                if summary.passed {
                    Button(continueLabel, action: onContinue)
                        .buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Skip", action: onContinue)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.top, 4)
        }
        .padding(28)
        .background(Theme.panel.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 8)
    }
}

/// The bar across the top of a lesson or song, with a close button.
struct SessionTopBar: View {
    let title: String
    let stepCount: Int
    let stepIndex: Int
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(Theme.panelRaised)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)

            if stepCount > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        Capsule()
                            .fill(index < stepIndex ? Theme.accent : (index == stepIndex ? Theme.textPrimary : Color(white: 0.3)))
                            .frame(height: 5)
                    }
                }
                .frame(maxWidth: 420)
            }
            Spacer()
            ConnectionBadge()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.panel)
    }
}

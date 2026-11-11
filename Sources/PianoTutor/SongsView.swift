import SwiftUI
import PianoTutorCore

/// The song library, grouped by difficulty.
struct SongsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.screenLayout) private var screen

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Songs")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text("Practise any tune at your own speed, one hand at a time or both together.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                }
                ForEach(1...3, id: \.self) { level in
                    levelSection(level)
                }
            }
            .padding(screen.compact ? 16 : 32)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func levelSection(_ level: Int) -> some View {
        let songs: [Song] = SongLibrary.songs.filter { $0.level == level }
        return VStack(alignment: .leading, spacing: 10) {
            Text(SongLibrary.levelName(level).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.accent)
            ForEach(songs) { song in
                SongRow(song: song)
            }
        }
    }
}

struct SongRow: View {
    @EnvironmentObject var model: AppModel
    let song: Song

    var body: some View {
        Button {
            model.activeSong = song
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.panelRaised)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(song.credit)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(song.score.hands.count > 1 ? "Both hands" : "Right hand")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.panelRaised)
                    .clipShape(Capsule())
                    .fixedSize()
                StarsView(stars: model.stars(forSong: song.id), size: 13)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum HandChoice: String, CaseIterable, Identifiable {
    case right
    case left
    case both

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .right: return "Right"
        case .left: return "Left"
        case .both: return "Both"
        }
    }

    var hands: Set<Hand> {
        switch self {
        case .right: return [.right]
        case .left: return [.left]
        case .both: return [.right, .left]
        }
    }
}

/// Plays one song with adjustable mode, hands and speed.
struct SongSessionView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.screenLayout) private var screen
    let song: Song

    @State private var perform: Bool = false
    @State private var handChoice: HandChoice = .right
    @State private var speed: Double = 1.0
    @State private var metronome: Bool = true
    @State private var noteNames: Bool = true
    @State private var keyHints: Bool = true

    private var twoHanded: Bool {
        return song.score.hands.count > 1
    }

    private var config: SessionConfig {
        let hands: Set<Hand> = twoHanded ? handChoice.hands : song.score.hands
        return SessionConfig(
            score: song.score,
            mode: perform ? .tempo : .wait,
            hands: hands,
            tempoScale: speed,
            metronome: metronome,
            noteNames: noteNames,
            keyHints: keyHints
        )
    }

    /// Changing any option restarts the player.
    private var configKey: String {
        return [
            perform ? "t" : "w",
            handChoice.rawValue,
            String(speed),
            metronome ? "m" : "-",
            noteNames ? "n" : "-",
            keyHints ? "k" : "-",
        ].joined(separator: "|")
    }

    var body: some View {
        VStack(spacing: 0) {
            if screen.short {
                // Not enough height for a row of its own, so the options share the top bar.
                SessionTopBar(title: song.credit, stepCount: 0, stepIndex: 0, onClose: { model.activeSong = nil }) {
                    options
                }
            } else {
                SessionTopBar(title: song.credit, stepCount: 0, stepIndex: 0, onClose: { model.activeSong = nil })
                options
                    .padding(.vertical, 10)
                    .background(Theme.panel.opacity(0.6))
            }
            ExerciseView(
                title: song.title,
                instruction: perform
                    ? "Play in time with the clicks. Your best result is saved."
                    : "The music waits for you. Switch to In time when you know the notes.",
                baseConfig: config,
                continueLabel: "Done",
                onContinue: { summary in
                    if summary.timed && twoHandedOrFull {
                        model.record(song: song.id, stars: summary.stars)
                    }
                    model.activeSong = nil
                }
            )
            .id(configKey)
        }
    }

    /// Stars only count when the whole song is played at full speed.
    private var twoHandedOrFull: Bool {
        let allHands: Bool = !twoHanded || handChoice == .both
        return allHands && speed >= 0.99
    }

    /// The row of options. It scrolls sideways when the screen is too narrow to show them all.
    private var options: some View {
        let pickerWidth: CGFloat = screen.compact ? 160 : 190
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: screen.compact ? 10 : 18) {
                Picker("Mode", selection: $perform) {
                    Text("Practice").tag(false)
                    Text("In time").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: pickerWidth)

                if twoHanded {
                    Picker("Hands", selection: $handChoice) {
                        ForEach(HandChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: pickerWidth)
                }

                Picker("Speed", selection: $speed) {
                    Text("60%").tag(0.6)
                    Text("80%").tag(0.8)
                    Text("100%").tag(1.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: pickerWidth)
                .disabled(!perform)

                Toggle("Metronome", isOn: $metronome)
                    .disabled(!perform)
                Toggle("Note names", isOn: $noteNames)
                Toggle("Key hints", isOn: $keyHints)
            }
            .toggleStyle(.button)
            .font(.system(size: 12, design: .rounded))
            .padding(.horizontal, screen.short ? 0 : (screen.narrow ? 12 : 20))
        }
    }
}

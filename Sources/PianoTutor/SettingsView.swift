import SwiftUI
import PianoTutorCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.screenLayout) private var screen
    @State private var confirmReset: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)

                keyboardSection
                microphoneSection
                soundSection
                timingSection
                progressSection
                supportSection
            }
            .padding(screen.compact ? 16 : 32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.accent)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func note(_ text: String) -> some View {
        SettingsNote(text: text)
    }

    private var keyboardSection: some View {
        section("Keyboard") {
            if model.midi.sourceNames.isEmpty {
                Label("No MIDI keyboard found", systemImage: "exclamationmark.circle")
                    .foregroundColor(Theme.textPrimary)
                note("Connect the keyboard's USB port to your " + Platform.deviceName + " with a data cable (some cables only charge) and switch the keyboard on. It appears here within a second or two.")
            } else {
                ForEach(model.midi.sourceNames, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.good)
                }
                LastNoteText(notes: model.lastNotes, source: .midi)
            }
            Button("Look again") {
                model.midi.refreshSources()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var microphoneSection: some View {
        section("Microphone") {
            Toggle("Listen to my piano when no MIDI keyboard is connected", isOn: $model.useMicrophone)
                .foregroundColor(Theme.textPrimary)
            if model.useMicrophone {
                microphoneStatus
            }
            note("For an acoustic piano, or a keyboard without USB. Put the " + Platform.deviceName + " near the piano. One note at a time is recognised anywhere; chords are recognised in lessons and songs, where the app knows which notes to listen for. The metronome can confuse it, so use headphones or keep the volume low. A MIDI keyboard is still quicker and more exact.")
            if model.useMicrophone {
                Toggle("Noisy room: only listen for the right notes", isOn: $model.micRightNotesOnly)
                    .foregroundColor(Theme.textPrimary)
                note("Talking and other sounds are mostly told apart from the piano, but not always. With this on, nothing the microphone hears is ever marked as a wrong note; the music simply waits for the right one.")
            }
        }
    }

    @ViewBuilder
    private var microphoneStatus: some View {
        if model.midi.isConnected {
            Label("Not listening: a MIDI keyboard is connected", systemImage: "pause.circle")
                .foregroundColor(Theme.textSecondary)
        } else {
            switch model.mic.state {
            case .listening:
                Label("Listening", systemImage: "mic.fill")
                    .foregroundColor(Theme.good)
                LastNoteText(notes: model.lastNotes, source: .microphone)
            case .asking:
                Label("Waiting for permission to use the microphone", systemImage: "mic")
                    .foregroundColor(Theme.textPrimary)
            case .denied:
                Label("Middle C is not allowed to use the microphone", systemImage: "mic.slash")
                    .foregroundColor(Theme.textPrimary)
                note(Platform.hasComputerKeys
                    ? "Allow it in System Settings → Privacy & Security → Microphone, then switch this off and on again."
                    : "Allow it in the Settings app → Privacy & Security → Microphone, then switch this off and on again.")
            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.circle")
                    .foregroundColor(Theme.textPrimary)
            case .off:
                EmptyView()
            }
        }
    }

    private var soundSection: some View {
        section("Sound") {
            HStack {
                Text("Volume")
                    .foregroundColor(Theme.textPrimary)
                Slider(value: $model.volume, in: 0...1)
                    .frame(maxWidth: 280)
            }
            Picker("Hear my playing through the " + Platform.deviceName, selection: $model.monitorMode) {
                ForEach(MonitorMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 460)
            note("Automatic stays silent for a MIDI keyboard, because it already has its own speakers, and plays a piano sound for the on-screen" + (Platform.hasComputerKeys ? " and computer" : "") + " keys. Notes heard through the microphone are never played back. The metronome and accompaniment always come from the " + Platform.deviceName + ".")
        }
    }

    private var timingSection: some View {
        section("Timing") {
            HStack {
                Text("Offset")
                    .foregroundColor(Theme.textPrimary)
                Slider(value: $model.timingOffsetMs, in: -100...200, step: 5)
                    .frame(maxWidth: 280)
                Text(String(Int(model.timingOffsetMs)) + " ms")
                    .foregroundColor(Theme.textSecondary)
                    .monospacedDigit()
            }
            note("If notes you play on the beat are often marked Late, raise this. Wireless headphones and speakers usually need 100 ms or more. If they are marked Early, lower it.")
        }
    }

    private var progressSection: some View {
        section("Progress") {
            Toggle("Unlock all lessons", isOn: $model.unlockAll)
                .foregroundColor(Theme.textPrimary)
            Button("Reset progress…") {
                confirmReset = true
            }
            .buttonStyle(SecondaryButtonStyle())
            .confirmationDialog("Reset all stars and completed lessons?", isPresented: $confirmReset) {
                Button("Reset progress", role: .destructive) {
                    model.resetProgress()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var supportSection: some View {
        section("Support Middle C") {
            note("Middle C has no ads and no tracking. If you enjoy learning with it, a coffee helps fund its development.")
            Link(destination: Links.buyMeACoffee) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}

/// A line of small explanatory text under a setting.
private struct SettingsNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The last note an input picked up. It observes `LastNotes` on its own, so that each note
/// played refreshes only this line rather than every view that watches `AppModel`.
private struct LastNoteText: View {
    enum Source {
        case midi
        case microphone
    }

    @ObservedObject var notes: LastNotes
    let source: Source

    var body: some View {
        switch source {
        case .midi:
            SettingsNote(text: "Play a key to check the connection. Last note received: " + (notes.midi ?? "none yet") + ".")
        case .microphone:
            SettingsNote(text: "Play a key to check. Last note heard: " + (notes.heard ?? "none yet") + ".")
        }
    }
}

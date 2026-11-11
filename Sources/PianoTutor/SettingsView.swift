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
                soundSection
                timingSection
                progressSection
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
        Text(text)
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
                note("Play a key to check the connection. Last note received: " + (model.lastMIDINote ?? "none yet") + ".")
            }
            Button("Look again") {
                model.midi.refreshSources()
            }
            .buttonStyle(SecondaryButtonStyle())
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
            note("Automatic stays silent for a MIDI keyboard, because it already has its own speakers, and plays a piano sound for the on-screen" + (Platform.hasComputerKeys ? " and computer" : "") + " keys. The metronome and accompaniment always come from the " + Platform.deviceName + ".")
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
}

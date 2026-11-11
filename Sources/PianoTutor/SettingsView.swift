import SwiftUI
import PianoTutorCore
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.screenLayout) private var screen
    @Environment(\.openURL) private var openURL
    @State private var confirmReset: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .scaledFont(30, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)

                keyboardSection
                microphoneSection
                soundSection
                timingSection
                languageSection
                progressSection
                feedbackSection
                websiteSection
            }
            .padding(screen.compact ? 16 : 32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .textCase(.uppercase)
                .scaledFont(11, weight: .bold)
                .foregroundStyle(Theme.accent)
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
                    .foregroundStyle(Theme.textPrimary)
                note(connectNote)
            } else {
                ForEach(model.midi.sourceNames, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.good)
                }
                LastNoteText(notes: model.lastNotes, source: .midi)
            }
            Button("Look again") {
                model.midi.refreshSources()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var connectNote: String {
        switch Platform.device {
        case .mac:
            return String(localized: "Connect the keyboard's USB port to your Mac with a data cable (some cables only charge) and switch the keyboard on. It appears here within a second or two.")
        case .iPad:
            return String(localized: "Connect the keyboard's USB port to your iPad with a data cable (some cables only charge) and switch the keyboard on. It appears here within a second or two.")
        case .iPhone:
            return String(localized: "Connect the keyboard's USB port to your iPhone with a data cable (some cables only charge) and switch the keyboard on. It appears here within a second or two.")
        }
    }

    private var microphoneSection: some View {
        section("Microphone") {
            Toggle("Listen to my piano when no MIDI keyboard is connected", isOn: $model.useMicrophone)
                .foregroundStyle(Theme.textPrimary)
            if model.useMicrophone {
                microphoneStatus
            }
            note(microphoneNote)
            if model.useMicrophone {
                Toggle("Noisy room: only listen for the right notes", isOn: $model.micRightNotesOnly)
                    .foregroundStyle(Theme.textPrimary)
                note(String(localized: "Talking and other sounds are mostly told apart from the piano, but not always. With this on, nothing the microphone hears is ever marked as a wrong note; the music simply waits for the right one."))
            }
        }
    }

    private var microphoneNote: String {
        switch Platform.device {
        case .mac:
            return String(localized: "For an acoustic piano, or a keyboard without USB. Put the Mac near the piano. One note at a time is recognised anywhere; chords are recognised in lessons and songs, where the app knows which notes to listen for. The metronome can confuse it, so use headphones or keep the volume low. A MIDI keyboard is still quicker and more exact.")
        case .iPad:
            return String(localized: "For an acoustic piano, or a keyboard without USB. Put the iPad near the piano. One note at a time is recognised anywhere; chords are recognised in lessons and songs, where the app knows which notes to listen for. The metronome can confuse it, so use headphones or keep the volume low. A MIDI keyboard is still quicker and more exact.")
        case .iPhone:
            return String(localized: "For an acoustic piano, or a keyboard without USB. Put the iPhone near the piano. One note at a time is recognised anywhere; chords are recognised in lessons and songs, where the app knows which notes to listen for. The metronome can confuse it, so use headphones or keep the volume low. A MIDI keyboard is still quicker and more exact.")
        }
    }

    @ViewBuilder
    private var microphoneStatus: some View {
        if model.midi.isConnected {
            Label("Not listening: a MIDI keyboard is connected", systemImage: "pause.circle")
                .foregroundStyle(Theme.textSecondary)
        } else {
            switch model.mic.state {
            case .listening:
                Label("Listening", systemImage: "mic.fill")
                    .foregroundStyle(Theme.good)
                LastNoteText(notes: model.lastNotes, source: .microphone)
            case .asking:
                Label("Waiting for permission to use the microphone", systemImage: "mic")
                    .foregroundStyle(Theme.textPrimary)
            case .denied:
                Label("Middle C is not allowed to use the microphone", systemImage: "mic.slash")
                    .foregroundStyle(Theme.textPrimary)
                note(Platform.hasComputerKeys
                    ? String(localized: "Allow it in System Settings → Privacy & Security → Microphone, then switch this off and on again.", comment: "Use the names of the macOS System Settings panes as they appear in this language")
                    : String(localized: "Allow it in the Settings app → Privacy & Security → Microphone, then switch this off and on again.", comment: "Use the names of the iOS Settings screens as they appear in this language"))
            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.circle")
                    .foregroundStyle(Theme.textPrimary)
            case .off:
                EmptyView()
            }
        }
    }

    private var soundSection: some View {
        section("Sound") {
            HStack {
                Text("Volume")
                    .foregroundStyle(Theme.textPrimary)
                Slider(value: $model.volume, in: 0...1)
                    .frame(maxWidth: 280)
            }
            Picker(selection: $model.monitorMode) {
                ForEach(MonitorMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            } label: {
                Text(monitorLabel)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 460)
            note(monitorNote)
        }
    }

    private var monitorLabel: String {
        switch Platform.device {
        case .mac: return String(localized: "Hear my playing through the Mac")
        case .iPad: return String(localized: "Hear my playing through the iPad")
        case .iPhone: return String(localized: "Hear my playing through the iPhone")
        }
    }

    private var monitorNote: String {
        switch Platform.device {
        case .mac:
            return String(localized: "Automatic stays silent for a MIDI keyboard, because it already has its own speakers, and plays a piano sound for the on-screen and computer keys. Notes heard through the microphone are never played back. The metronome and accompaniment always come from the Mac.", comment: "\"Automatic\" is the name of the first option above; use the same word")
        case .iPad:
            return String(localized: "Automatic stays silent for a MIDI keyboard, because it already has its own speakers, and plays a piano sound for the on-screen keys. Notes heard through the microphone are never played back. The metronome and accompaniment always come from the iPad.", comment: "\"Automatic\" is the name of the first option above; use the same word")
        case .iPhone:
            return String(localized: "Automatic stays silent for a MIDI keyboard, because it already has its own speakers, and plays a piano sound for the on-screen keys. Notes heard through the microphone are never played back. The metronome and accompaniment always come from the iPhone.", comment: "\"Automatic\" is the name of the first option above; use the same word")
        }
    }

    private var timingSection: some View {
        section("Timing") {
            HStack {
                Text("Offset", comment: "Timing setting: how much to shift the judging of notes, in milliseconds")
                    .foregroundStyle(Theme.textPrimary)
                Slider(value: $model.timingOffsetMs, in: -100...200, step: 5)
                    .frame(maxWidth: 280)
                Text(
                    Measurement(value: model.timingOffsetMs, unit: UnitDuration.milliseconds),
                    format: .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
                )
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
            }
            note(String(localized: "If notes you play on the beat are often marked Late, raise this. Wireless headphones and speakers usually need 100 ms or more. If they are marked Early, lower it.", comment: "\"Late\" and \"Early\" are the feedback words shown on the staff; use the same translations"))
        }
    }

    /// The app follows the system's language choice; Apple's guidance is to send people to
    /// Settings to change it rather than offer a picker of our own.
    private var languageSection: some View {
        section("Language") {
            #if os(iOS)
            note(String(localized: "Middle C uses the language of your device. To use a different language for Middle C only, choose it on the app's page in the Settings app."))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            #else
            note(String(localized: "Middle C uses the language of your Mac. To use a different language for Middle C only, add it in System Settings → General → Language & Region → Applications.", comment: "Use the names of the macOS System Settings panes as they appear in this language"))
            #endif
        }
    }

    private var progressSection: some View {
        section("Progress") {
            Toggle("Unlock all lessons", isOn: $model.unlockAll)
                .foregroundStyle(Theme.textPrimary)
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

extension SettingsView {
    private var feedbackSection: some View {
        section("Feedback") {
            note(String(localized: "Found a problem, or have an idea for Middle C? Post it on the feedback board, where you can also vote for other people's ideas."))
            Link(destination: Links.feedback) {
                Label("Report a problem or suggest an idea", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var websiteSection: some View {
        section("Website") {
            note(String(localized: "Help with keyboards and the microphone, answers to common questions, and the privacy policy are on the Middle C website."))
            Link(destination: Links.website) {
                // The address, which is not translated.
                Label {
                    Text(verbatim: Links.websiteName)
                } icon: {
                    Image(systemName: "globe")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

/// A line of small explanatory text under a setting.
private struct SettingsNote: View {
    let text: String

    var body: some View {
        Text(text)
            .scaledFont(12)
            .foregroundStyle(Theme.textSecondary)
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
        SettingsNote(text: text)
    }

    private var text: String {
        switch source {
        case .midi:
            if let note = notes.midi {
                return String(localized: "Play a key to check the connection. Last note received: \(note).", comment: "The placeholder is a note name with its octave, such as C4")
            }
            return String(localized: "Play a key to check the connection. No note received yet.")
        case .microphone:
            if let note = notes.heard {
                return String(localized: "Play a key to check. Last note heard: \(note).", comment: "The placeholder is a note name with its octave, such as C4")
            }
            return String(localized: "Play a key to check. No note heard yet.")
        }
    }
}

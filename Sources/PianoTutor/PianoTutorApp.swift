import SwiftUI
import PianoTutorCore
#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when the app is launched with `swift run` instead of from an app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
#endif

@main
struct PianoTutorApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()

    var body: some Scene {
        #if os(macOS)
        window
            .defaultSize(width: 1280, height: 820)
            .commands {
                CommandGroup(replacing: .newItem) {}
                CommandGroup(after: .help) {
                    Button(String(localized: "Middle C Website", comment: "Help menu item that opens the app's website")) {
                        NSWorkspace.shared.open(Links.website)
                    }
                    Button("Report a Problem or Suggest an Idea…") {
                        NSWorkspace.shared.open(Links.feedback)
                    }
                }
            }
        #else
        window
        #endif
    }

    private var window: some Scene {
        // The app's name is a brand and stays the same in every language.
        WindowGroup(Text(verbatim: "Middle C")) {
            RootView()
                .environmentObject(model)
                .environmentObject(model.input)
                .onAppear {
                    model.start()
                }
                .onChange(of: scenePhase) { phase in
                    // iOS stops the audio engine in the background and after a phone call.
                    if phase == .active {
                        model.resumeAudio()
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let lesson = model.activeLesson {
                    LessonView(lesson: lesson)
                        .id(lesson.id)
                } else if let song = model.activeSong {
                    SongSessionView(song: song)
                        .id(song.id)
                } else {
                    MainView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.screenLayout, ScreenLayout(size: proxy.size))
        }
        .background(Theme.background.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 1080, minHeight: 720)
        #else
        // Keeps a swipe along the bottom keys from sending the app to the Home Screen.
        .defersSystemGestures(on: .bottom)
        #endif
        .preferredColorScheme(.dark)
    }
}

/// The selected section with its navigation: a sidebar on a Mac or iPad,
/// an icon rail on an iPhone held sideways and a tab bar on an upright iPhone.
struct MainView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.screenLayout) private var screen

    var body: some View {
        if screen.narrow {
            VStack(spacing: 0) {
                content
                tabBar
            }
        } else {
            HStack(spacing: 0) {
                if screen.short {
                    rail
                } else {
                    sidebar
                }
                content
            }
        }
    }

    private var content: some View {
        Group {
            switch model.section {
            case .learn: LearnView()
            case .songs: SongsView()
            case .freePlay: FreePlayView()
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "pianokeys.inverse")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
                Text(verbatim: "Middle C")
                    .scaledFont(20, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.bottom, 22)

            ForEach(SidebarSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.symbol)
                            .frame(width: 22)
                        Text(section.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                    }
                    .scaledFont(15, weight: .medium)
                    .foregroundStyle(model.section == section ? Theme.ink : Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(model.section == section ? Theme.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.section == section ? .isSelected : [])
            }

            Spacer()
            ConnectionBadge()
        }
        .padding(18)
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Theme.panel)
        // A fixed-width column: past this size the section names would break in the middle of words.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var rail: some View {
        VStack(spacing: 6) {
            ForEach(SidebarSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    Image(systemName: section.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(model.section == section ? Theme.ink : Theme.textPrimary)
                        .frame(width: 44, height: 40)
                        .background(model.section == section ? Theme.accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(model.section == section ? .isSelected : [])
            }
            Spacer(minLength: 0)
            ConnectionBadge(dotOnly: true)
        }
        .padding(.vertical, 10)
        .frame(width: 60)
        .frame(maxHeight: .infinity)
        .background(Theme.panel)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SidebarSection.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: section.symbol)
                            .font(.system(size: 18, weight: .medium))
                            .frame(height: 22)
                        Text(section.title)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(model.section == section ? Theme.accent : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.section == section ? .isSelected : [])
            }
        }
        .background(Theme.panel)
    }
}

/// Shows whether a MIDI keyboard is plugged in, or the microphone is listening instead.
struct ConnectionBadge: View {
    @EnvironmentObject var model: AppModel
    var dotOnly: Bool = false

    var body: some View {
        if dotOnly {
            dot
                .accessibilityLabel(title)
        } else {
            full
        }
    }

    private var title: String {
        if model.midi.isConnected { return String(localized: "Keyboard connected", comment: "Connection status") }
        return model.mic.isListening
            ? String(localized: "Microphone listening", comment: "Connection status")
            : String(localized: "No keyboard", comment: "Connection status")
    }

    /// The keyboard's name, or what to do without one.
    private var detail: String {
        if let name = model.midi.sourceNames.first { return name }
        return model.mic.isListening
            ? String(localized: "Play your piano", comment: "Connection status detail while the microphone is listening")
            : String(localized: "Using on-screen keys", comment: "Connection status detail when nothing is connected")
    }

    private var dot: some View {
        Circle()
            .fill(model.midi.isConnected || model.mic.isListening ? Theme.good : Color(white: 0.45))
            .frame(width: 9, height: 9)
    }

    private var full: some View {
        HStack(alignment: .top, spacing: 8) {
            dot
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(12, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .scaledFont(11)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

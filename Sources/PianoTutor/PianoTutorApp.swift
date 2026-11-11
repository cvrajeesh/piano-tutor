import SwiftUI
import AppKit
import PianoTutorCore

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

@main
struct PianoTutorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Piano Tutor") {
            RootView()
                .environmentObject(model)
                .environmentObject(model.input)
                .onAppear {
                    model.start()
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
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
        .frame(minWidth: 1080, minHeight: 720)
        .preferredColorScheme(.dark)
    }
}

/// Sidebar plus the selected section.
struct MainView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
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
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "pianokeys.inverse")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.accent)
                Text("Piano Tutor")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
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
                        Spacer()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(model.section == section ? Theme.ink : Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(model.section == section ? Theme.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
            ConnectionBadge()
        }
        .padding(18)
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Theme.panel)
    }
}

/// Shows whether a MIDI keyboard is plugged in.
struct ConnectionBadge: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(model.midi.isConnected ? Theme.good : Color(white: 0.45))
                .frame(width: 9, height: 9)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.midi.isConnected ? "Keyboard connected" : "No keyboard")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(model.midi.sourceNames.first ?? "Using on-screen keys")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

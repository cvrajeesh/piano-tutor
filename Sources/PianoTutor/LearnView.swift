import SwiftUI
import PianoTutorCore

/// The course map: every unit and its lessons.
struct LearnView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.screenLayout) private var screen

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                if !model.midi.isConnected && !model.mic.isListening {
                    ConnectHint()
                }
                ForEach(Array(Curriculum.units.enumerated()), id: \.element.id) { index, unit in
                    UnitSection(number: index + 1, unit: unit)
                }
            }
            .padding(screen.compact ? 16 : 32)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Learn")
                    .scaledFont(30, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("Work through the lessons in order. Each one takes a few minutes.")
                    .scaledFont(14)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let next = model.nextLesson, model.isUnlocked(next) {
                Button {
                    model.activeLesson = next
                } label: {
                    if model.progress.lessonStars.isEmpty {
                        Label("Start", systemImage: "play.fill")
                    } else {
                        Label("Continue", systemImage: "play.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(small: screen.compact))
                .fixedSize()
            }
        }
    }
}

struct ConnectHint: View {
    static var message: String {
        switch Platform.device {
        case .mac:
            #if os(macOS)
            let row: String = ComputerKeyboard.labels(ComputerKeyboard.whiteKeys)
            #else
            let row: String = "A S D F G H J K"
            #endif
            return String(localized: "Plug the USB port on the back of your keyboard into your Mac and switch the keyboard on. It is recognised automatically; no driver is needed. Until then you can click the on-screen keys or use the \(row) row of your computer keyboard.", comment: "The placeholder is the letters on the computer keys that play the piano, as printed in the user's keyboard layout, such as \"A S D F G H J K\"")
        case .iPad:
            return String(localized: "Connect the USB port on the back of your keyboard to your iPad (you may need a USB-C or Lightning adapter) and switch the keyboard on. It is recognised automatically. Until then you can play the on-screen keys.")
        case .iPhone:
            return String(localized: "Connect the USB port on the back of your keyboard to your iPhone (you may need a USB-C or Lightning adapter) and switch the keyboard on. It is recognised automatically. Until then you can play the on-screen keys.")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cable.connector")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 5) {
                Text("Connect your keyboard")
                    .scaledFont(15, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                Text(ConnectHint.message)
                    .scaledFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No MIDI? Middle C can listen to a piano or any keyboard through the microphone. Turn it on in Settings.")
                    .scaledFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct UnitSection: View {
    @EnvironmentObject var model: AppModel
    let number: Int
    let unit: CourseUnit

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 150, maximum: 320), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Unit \(number)", comment: "Heading above each unit of the course, shown in capitals")
                    .textCase(.uppercase)
                    .scaledFont(11, weight: .bold)
                    .foregroundStyle(Theme.accent)
                Text(unit.title.courseLocalized)
                    .scaledFont(20, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text(unit.summary.courseLocalized)
                    .scaledFont(13)
                    .foregroundStyle(Theme.textSecondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(unit.lessons) { lesson in
                    LessonCard(lesson: lesson)
                }
            }
        }
    }
}

struct LessonCard: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson

    var body: some View {
        let unlocked: Bool = model.isUnlocked(lesson)
        let stars: Int = model.stars(forLesson: lesson.id)

        Button {
            model.activeLesson = lesson
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if unlocked {
                        StarsView(stars: stars, size: 13)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    Spacer()
                    if stars > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.good)
                    }
                }
                Text(lesson.title.courseLocalized)
                    .scaledFont(15, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(lesson.summary.courseLocalized)
                    .scaledFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    // Three lines: summaries run longer in some languages than in English.
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(unlocked ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

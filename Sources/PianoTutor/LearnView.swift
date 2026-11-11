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
                if !model.midi.isConnected {
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
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text("Work through the lessons in order. Each one takes a few minutes.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let next = model.nextLesson, model.isUnlocked(next) {
                Button {
                    model.activeLesson = next
                } label: {
                    Label(model.progress.lessonStars.isEmpty ? "Start" : "Continue", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(small: screen.compact))
                .fixedSize()
            }
        }
    }
}

struct ConnectHint: View {
    static var message: String {
        if Platform.hasComputerKeys {
            return "Plug the USB port on the back of your keyboard into your Mac and switch the keyboard on. It is recognised automatically; no driver is needed. Until then you can click the on-screen keys or use the A S D F G H J K row of your computer keyboard."
        }
        return "Connect the USB port on the back of your keyboard to your " + Platform.deviceName
            + " (you may need a USB-C or Lightning adapter) and switch the keyboard on. It is recognised automatically. Until then you can play the on-screen keys."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cable.connector")
                .font(.system(size: 22))
                .foregroundColor(Theme.accent)
            VStack(alignment: .leading, spacing: 5) {
                Text("Connect your keyboard")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(ConnectHint.message)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
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
                Text("UNIT " + String(number))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.accent)
                Text(unit.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(unit.summary)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
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
                            .foregroundColor(Color(white: 0.5))
                    }
                    Spacer()
                    if stars > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.good)
                    }
                }
                Text(lesson.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(lesson.summary)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
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

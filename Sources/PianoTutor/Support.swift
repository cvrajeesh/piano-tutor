import SwiftUI
import Darwin
#if os(macOS)
import AppKit
#endif
import PianoTutorCore

/// Seconds on the same clock CoreMIDI uses for its timestamps.
enum HostClock {
    private static let secondsPerTick: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000.0
    }()

    static var now: TimeInterval {
        return Double(mach_absolute_time()) * secondsPerTick
    }

    static func seconds(fromHostTime ticks: UInt64) -> TimeInterval {
        return Double(ticks) * secondsPerTick
    }
}

/// Web pages the app links to. No tip or donation links: App Store guideline 3.1.1
/// only allows tips through In-App Purchase. Buy Me a Coffee is on the website.
enum Links {
    static let feedback = URL(string: "https://middlec.userjot.com")!
}

/// Names the device in instructions ("Connect the keyboard to your iPad").
enum Platform {
    static var deviceName: String {
        #if os(macOS)
        return "Mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad"
        #endif
    }

    static var hasComputerKeys: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}

/// VoiceOver announcements, for feedback that appears without the focus moving.
enum Announcer {
    static func announce(_ text: String) {
        #if os(macOS)
        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
        #else
        UIAccessibility.post(notification: .announcement, argument: text)
        #endif
    }

    /// How VoiceOver should say a key: "Middle C" for C4, otherwise for example "F♯3".
    static func spokenName(ofKey midi: Int) -> String {
        if midi == 60 { return "Middle C" }
        return Pitch.fromMIDI(midi).fullName
    }
}

/// How much room the window has. Set once by `RootView` so that every screen can adapt:
/// `narrow` is an iPhone held upright or a slim iPad split view, `short` an iPhone on its side.
struct ScreenLayout: Equatable {
    var narrow: Bool = false
    var short: Bool = false

    init(size: CGSize) {
        narrow = size.width < 700
        short = size.height < 500
    }

    init() {}

    var compact: Bool { return narrow || short }
}

extension EnvironmentValues {
    @Entry var screenLayout = ScreenLayout()
}

/// The app's rounded system font, sized to follow the reader's text size setting (Dynamic Type).
/// `size` is the size at the default setting.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: ScaledFont.textStyle(near: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: .rounded))
    }

    /// The text style whose default size is closest, so that the text grows at the same rate as system text of that size.
    private static func textStyle(near size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2      // 11 pt
        case ..<12.5: return .caption       // 12 pt
        case ..<14: return .footnote        // 13 pt
        case ..<15.5: return .subheadline   // 15 pt
        case ..<16.5: return .callout       // 16 pt
        case ..<18.5: return .body          // 17 pt
        case ..<21: return .title3          // 20 pt
        case ..<25: return .title2          // 22 pt
        case ..<31: return .title           // 28 pt
        default: return .largeTitle         // 34 pt
        }
    }
}

extension View {
    /// The app's rounded font at `size` points, scaled with the reader's text size.
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }

    /// For screens where you play: the staff and keyboard need most of the room, so the text
    /// stops growing at the largest standard size instead of going on to the accessibility sizes.
    /// Screens that scroll (the lists, Settings, lesson explanations) follow every size.
    func playingScreenTextLimit() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension Score {
    /// The lowest and highest key the given hands play, used to place a cut-down keyboard.
    func keyRange(hands: Set<Hand>) -> ClosedRange<Int>? {
        var low: Int? = nil
        var high: Int? = nil
        for note in notes where hands.contains(note.hand) {
            for pitch in note.pitches {
                low = min(low ?? pitch.midi, pitch.midi)
                high = max(high ?? pitch.midi, pitch.midi)
            }
        }
        guard let low = low, let high = high else { return nil }
        return low...high
    }
}

enum Theme {
    static let background = Color(red: 0.07, green: 0.09, blue: 0.14)
    static let panel = Color(red: 0.12, green: 0.15, blue: 0.22)
    static let panelRaised = Color(red: 0.17, green: 0.20, blue: 0.28)
    static let paper = Color(red: 0.99, green: 0.97, blue: 0.92)
    static let ink = Color(red: 0.11, green: 0.13, blue: 0.19)
    static let accent = Color(red: 0.98, green: 0.72, blue: 0.26)
    static let rightHand = Color(red: 0.13, green: 0.56, blue: 0.80)
    static let leftHand = Color(red: 0.90, green: 0.42, blue: 0.30)
    static let good = Color(red: 0.18, green: 0.66, blue: 0.40)
    static let bad = Color(red: 0.86, green: 0.25, blue: 0.27)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.72)

    static func hand(_ hand: Hand) -> Color {
        return hand == .right ? rightHand : leftHand
    }
}

/// A row of up to three stars.
struct StarsView: View {
    let stars: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: size * 0.15) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index < stars ? Theme.accent : Color(white: 0.4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(stars) + " of 3 stars")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    /// Tighter padding for small screens.
    var small: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(small ? 14 : 15, weight: .semibold)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, small ? 14 : 22)
            .padding(.vertical, small ? 7 : 10)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.7 : 1.0))
            .clipShape(Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var small: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(small ? 14 : 15, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, small ? 12 : 18)
            .padding(.vertical, small ? 7 : 10)
            .background(Theme.panelRaised.opacity(configuration.isPressed ? 0.6 : 1.0))
            .clipShape(Capsule())
    }
}

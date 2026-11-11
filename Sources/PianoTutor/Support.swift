import SwiftUI
import Darwin
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

/// Web pages the app links to.
enum Links {
    static let buyMeACoffee = URL(string: "https://buymeacoffee.com/liskovlabs")!
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

private struct ScreenLayoutKey: EnvironmentKey {
    static let defaultValue = ScreenLayout()
}

extension EnvironmentValues {
    var screenLayout: ScreenLayout {
        get { return self[ScreenLayoutKey.self] }
        set { self[ScreenLayoutKey.self] = newValue }
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
                    .foregroundColor(index < stars ? Theme.accent : Color(white: 0.4))
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
            .font(.system(size: small ? 14 : 15, weight: .semibold, design: .rounded))
            .foregroundColor(Theme.ink)
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
            .font(.system(size: small ? 14 : 15, weight: .medium, design: .rounded))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, small ? 12 : 18)
            .padding(.vertical, small ? 7 : 10)
            .background(Theme.panelRaised.opacity(configuration.isPressed ? 0.6 : 1.0))
            .clipShape(Capsule())
    }
}

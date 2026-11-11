import SwiftUI
import PianoTutorCore

/// Positions of the keys inside a rectangle. By default all 61 keys (C2 to C7) are laid out;
/// on a small screen only a window of `whiteCount` white keys starting at `firstWhite` is shown.
struct KeyboardGeometry {
    let size: CGSize
    let whiteNotes: [Int]
    let whiteWidth: CGFloat
    let firstWhite: Int

    /// How many white keys lie below each pitch class within one octave.
    private static let whitesBelow: [Int] = [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6]

    /// Every white key from C2 to C7.
    static let allWhites: [Int] = {
        var whites: [Int] = []
        for midi in KeyboardRange.lowest...KeyboardRange.highest where !KeyboardRange.isBlack(midi) {
            whites.append(midi)
        }
        return whites
    }()

    init(size: CGSize, firstWhite: Int = 0, whiteCount: Int? = nil) {
        let all: [Int] = KeyboardGeometry.allWhites
        let count: Int = min(max(whiteCount ?? all.count, 1), all.count)
        let first: Int = min(max(firstWhite, 0), all.count - count)
        self.size = size
        self.firstWhite = first
        self.whiteNotes = Array(all[first..<(first + count)])
        self.whiteWidth = size.width / CGFloat(count)
    }

    var blackWidth: CGFloat { return whiteWidth * 0.62 }
    var blackHeight: CGFloat { return size.height * 0.62 }

    var lowest: Int { return whiteNotes.first ?? KeyboardRange.lowest }
    var highest: Int { return whiteNotes.last ?? KeyboardRange.highest }

    /// The visible keys, lowest first.
    var notes: ClosedRange<Int> { return lowest...highest }

    /// Index among all white keys of this key, or for a black key of the white key to its right.
    static func whiteIndex(_ midi: Int) -> Int {
        let relative: Int = midi - KeyboardRange.lowest
        let octave: Int = relative / 12
        let pitchClass: Int = relative % 12
        return octave * 7 + whitesBelow[pitchClass]
    }

    func rect(for midi: Int) -> CGRect {
        let index: CGFloat = CGFloat(KeyboardGeometry.whiteIndex(midi) - firstWhite)
        if KeyboardRange.isBlack(midi) {
            return CGRect(x: index * whiteWidth - blackWidth / 2, y: 0, width: blackWidth, height: blackHeight)
        }
        return CGRect(x: index * whiteWidth, y: 0, width: whiteWidth, height: size.height)
    }

    func key(at point: CGPoint) -> Int? {
        if point.x < 0 || point.x >= size.width || point.y < 0 || point.y > size.height { return nil }
        if point.y <= blackHeight {
            for midi in notes where KeyboardRange.isBlack(midi) {
                if rect(for: midi).contains(point) { return midi }
            }
        }
        let index: Int = min(max(Int(point.x / whiteWidth), 0), whiteNotes.count - 1)
        return whiteNotes[index]
    }

    /// Where a window of `count` white keys should start.
    /// It is centred on `focus` (or around Middle C), moved by `shift` white keys,
    /// and finally nudged so that the keys in `mustShow` are visible if they fit.
    static func windowStart(count: Int, focus: ClosedRange<Int>?, mustShow: [Int], shift: Int) -> Int {
        let limit: Int = max(allWhites.count - count, 0)
        func span(_ keys: [Int]) -> (low: Int, high: Int)? {
            let inRange: [Int] = keys.filter { $0 >= KeyboardRange.lowest && $0 <= KeyboardRange.highest }
            guard let low = inRange.min(), let high = inRange.max() else { return nil }
            // A black key needs the white keys on both sides of it.
            return (whiteIndex(low) - (KeyboardRange.isBlack(low) ? 1 : 0), whiteIndex(high))
        }

        var start: Int
        if let focus = focus, let wanted = span([focus.lowerBound, focus.upperBound]) {
            start = (wanted.low + wanted.high + 1 - count) / 2
        } else {
            // Middle C a little left of centre, since most beginner music sits just above it.
            start = whiteIndex(60) - count * 2 / 5
        }
        start = min(max(start + shift, 0), limit)

        if let needed = span(mustShow), needed.high - needed.low < count {
            if needed.low < start { start = needed.low }
            if needed.high > start + count - 1 { start = needed.high - count + 1 }
        }
        return min(max(start, 0), limit)
    }
}

#if os(iOS)
/// Reports every finger on the keys, so that chords can be played on a touch screen.
private struct TouchSurface: UIViewRepresentable {
    var onChange: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onChange = onChange
    }

    final class TouchView: UIView {
        var onChange: (([CGPoint]) -> Void)?
        private var active: Set<UITouch> = []

        private func report() {
            onChange?(active.map { $0.location(in: self) })
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            active.formUnion(touches)
            report()
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            report()
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            active.subtract(touches)
            report()
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            active.subtract(touches)
            report()
        }
    }
}
#endif

/// Lets VoiceOver users play the keys by touch, as on a real instrument, instead of exploring them.
private struct DirectTouch: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            content.accessibilityAddTraits(.allowsDirectInteraction)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// The on-screen keyboard. It mirrors what is played, lights up the next keys
/// and can be clicked or, on a touch screen, played with several fingers.
struct KeyboardView: View {
    var held: Set<Int> = []
    var targets: [Int: KeyTarget] = [:]
    var good: Set<Int> = []
    var wrong: Set<Int> = []
    var marks: [KeyMark] = []
    var firstWhite: Int = 0
    var whiteCount: Int? = nil
    var onPress: (Int) -> Void = { _ in }
    var onRelease: (Int) -> Void = { _ in }

    @State private var pressed: Set<Int> = []

    private func geometry(_ size: CGSize) -> KeyboardGeometry {
        return KeyboardGeometry(size: size, firstWhite: firstWhite, whiteCount: whiteCount)
    }

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                draw(context, geometry(size))
            }
            .clipped()
            .contentShape(Rectangle())
            #if os(iOS)
            .overlay(
                TouchSurface { points in
                    touched(at: points, geometry(proxy.size))
                }
            )
            #else
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        touched(at: [value.location], geometry(proxy.size))
                    }
                    .onEnded { _ in
                        touched(at: [], geometry(proxy.size))
                    }
            )
            #endif
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Piano keyboard")
        .accessibilityValue(spokenState)
        .modifier(DirectTouch())
        .onDisappear {
            for note in pressed {
                onRelease(note)
            }
            pressed = []
        }
    }

    /// What VoiceOver says about the keys: which to play next (or which are marked), and which are held down.
    private var spokenState: String {
        var parts: [String] = []
        if !targets.isEmpty {
            let keys: [String] = targets.keys.sorted().map { midi in
                let name: String = Announcer.spokenName(ofKey: midi)
                if let finger = targets[midi]?.finger {
                    return String(localized: "\(name), finger \(finger)", comment: "VoiceOver: a key to play and the finger to play it with, such as \"E4, finger 3\"")
                }
                return name
            }
            parts.append(String(localized: "Play \(Announcer.list(keys)).", comment: "VoiceOver: the keys to play next; the placeholder is a list of keys, such as \"C4 and E4\""))
        } else if !marks.isEmpty {
            let keys: [String] = marks.map { Announcer.spokenName(ofKey: $0.midi) }
            parts.append(String(localized: "Marked: \(Announcer.list(keys)).", comment: "VoiceOver: the keys a lesson points out; the placeholder is a list of keys"))
        }
        if !held.isEmpty {
            let keys: [String] = held.sorted().map { Announcer.spokenName(ofKey: $0) }
            parts.append(String(localized: "Holding \(Announcer.list(keys)).", comment: "VoiceOver: the keys held down; the placeholder is a list of keys"))
        }
        return parts.joined(separator: " ")
    }

    /// Called with the position of every finger (or the mouse) that is down on the keys.
    private func touched(at points: [CGPoint], _ geometry: KeyboardGeometry) {
        let now: Set<Int> = Set(points.compactMap { geometry.key(at: $0) })
        if now == pressed { return }
        let released: Set<Int> = pressed.subtracting(now)
        let added: Set<Int> = now.subtracting(pressed)
        pressed = now
        for note in released {
            onRelease(note)
        }
        for note in added.sorted() {
            onPress(note)
        }
    }

    private func mark(for midi: Int) -> KeyMark? {
        return marks.first { $0.midi == midi }
    }

    private func fillColor(_ midi: Int, black: Bool) -> Color {
        if wrong.contains(midi) { return Theme.bad }
        if good.contains(midi) { return Theme.good }
        if let target = targets[midi] { return Theme.hand(target.hand) }
        if let found = mark(for: midi) {
            if let hand = found.hand { return Theme.hand(hand) }
            return Theme.accent
        }
        if held.contains(midi) {
            return black ? Color(white: 0.45) : Color(white: 0.70)
        }
        return black ? Color(white: 0.09) : Color(white: 0.97)
    }

    private func isHighlighted(_ midi: Int) -> Bool {
        return wrong.contains(midi) || good.contains(midi) || targets[midi] != nil || mark(for: midi) != nil
    }

    private func label(for midi: Int) -> String? {
        if let target = targets[midi] {
            if let finger = target.finger { return String(finger) }
            return nil
        }
        return mark(for: midi)?.label?.text
    }

    private func labelColor(for midi: Int) -> Color {
        if targets[midi] != nil { return .white }
        if let found = mark(for: midi), found.hand == nil { return Theme.ink }
        return .white
    }

    private func draw(_ context: GraphicsContext, _ geometry: KeyboardGeometry) {
        let size: CGSize = geometry.size
        let whiteWidth: CGFloat = geometry.whiteWidth

        // White keys
        for midi in geometry.whiteNotes {
            let rect: CGRect = geometry.rect(for: midi).insetBy(dx: 0.75, dy: 0)
            let path = Path(roundedRect: rect, cornerRadius: min(4, whiteWidth * 0.18))
            context.fill(path, with: .color(fillColor(midi, black: false)))
        }

        // Black keys
        for midi in geometry.notes where KeyboardRange.isBlack(midi) {
            let rect: CGRect = geometry.rect(for: midi)
            let path = Path(roundedRect: rect, cornerRadius: min(3, whiteWidth * 0.12))
            context.fill(path, with: .color(fillColor(midi, black: true)))
            if isHighlighted(midi) {
                context.stroke(path, with: .color(Color.black.opacity(0.5)), lineWidth: 1)
            }
        }

        // Labels
        let fontSize: CGFloat = min(max(whiteWidth * 0.5, 9), 15)
        for midi in geometry.notes {
            let rect: CGRect = geometry.rect(for: midi)
            let black: Bool = KeyboardRange.isBlack(midi)
            let baseY: CGFloat = black ? rect.maxY - fontSize * 0.95 : size.height - fontSize * 1.0

            if let text = label(for: midi) {
                // Note names and words vary in length between languages (C, Sol, ファ, Do central).
                let color: Color = labelColor(for: midi)
                context.drawFitted(at: CGPoint(x: rect.midX, y: baseY), size: fontSize, maxWidth: rect.width - 3) { size in
                    Text(verbatim: text)
                        .font(.system(size: size, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
            } else if !black && midi % 12 == 0 && !isHighlighted(midi) {
                // Name every C; Middle C gets a dot as a landmark.
                let name: String = NoteNaming.current.fullName(midi: midi)
                context.drawFitted(at: CGPoint(x: rect.midX, y: baseY), size: fontSize * 0.72, maxWidth: rect.width - 3) { size in
                    Text(verbatim: name)
                        .font(.system(size: size, weight: .medium, design: .rounded))
                        .foregroundColor(Color(white: 0.45))
                }
                if midi == 60 {
                    let dot = CGRect(x: rect.midX - 2.5, y: baseY - fontSize * 1.1, width: 5, height: 5)
                    context.fill(Path(ellipseIn: dot), with: .color(Theme.accent))
                }
            }
        }
    }
}

/// The keyboard as it appears at the bottom of every screen, wired to the shared input.
/// When the screen is too small for 61 playable keys it shows a section of the keyboard
/// around `focus` (the range of the music being played) with buttons to move along it.
struct KeyboardPanel: View {
    @EnvironmentObject var input: InputHub
    @Environment(\.screenLayout) private var screen
    var targets: [Int: KeyTarget] = [:]
    var good: Set<Int> = []
    var wrong: Set<Int> = []
    var marks: [KeyMark] = []
    var focus: ClosedRange<Int>? = nil

    /// How far the player has moved the visible section, in white keys.
    @State private var shift: Int = 0

    /// The narrowest white key that all 61 keys may be squeezed to before the keyboard is cut down.
    private static let minimumFullWidth: CGFloat = 21.5
    private static let comfortableWidth: CGFloat = 30
    private static let arrowWidth: CGFloat = 26

    private var edge: CGFloat { return screen.compact ? 6 : 14 }

    var body: some View {
        GeometryReader { proxy in
            let total: Int = KeyboardGeometry.allWhites.count
            let width: CGFloat = proxy.size.width
            if !screen.short && width / CGFloat(total) >= KeyboardPanel.minimumFullWidth {
                keys(firstWhite: 0, count: total)
            } else {
                let room: CGFloat = width - 2 * (KeyboardPanel.arrowWidth + 4)
                let count: Int = min(max(Int(room / KeyboardPanel.comfortableWidth), 8), total)
                let auto: Int = start(count: count, shift: 0)
                let first: Int = start(count: count, shift: shift)
                HStack(spacing: 4) {
                    arrow("chevron.left", label: "Lower keys", enabled: first > 0) {
                        shift = max(first - 7, 0) - auto
                    }
                    keys(firstWhite: first, count: count)
                    arrow("chevron.right", label: "Higher keys", enabled: first < total - count) {
                        shift = min(first + 7, total - count) - auto
                    }
                }
            }
        }
        .frame(height: screen.short ? 100 : 150)
        .padding(.horizontal, edge)
        .padding(.top, screen.compact ? 6 : 10)
        .padding(.bottom, screen.compact ? 6 : 14)
        .background(Theme.panel)
        .onChange(of: focus) { _ in
            shift = 0
        }
    }

    private func start(count: Int, shift: Int) -> Int {
        let highlighted: [Int] = Array(targets.keys) + marks.map { $0.midi }
        return KeyboardGeometry.windowStart(count: count, focus: focus, mustShow: highlighted, shift: shift)
    }

    private func keys(firstWhite: Int, count: Int) -> some View {
        KeyboardView(
            held: input.held,
            targets: targets,
            good: good,
            wrong: wrong,
            marks: marks,
            firstWhite: firstWhite,
            whiteCount: count,
            onPress: { midi in input.press(midi, source: .mouse) },
            onRelease: { midi in input.release(midi, source: .mouse) }
        )
    }

    private func arrow(_ symbol: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: KeyboardPanel.arrowWidth)
                .frame(maxHeight: .infinity)
                .background(Theme.panelRaised)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

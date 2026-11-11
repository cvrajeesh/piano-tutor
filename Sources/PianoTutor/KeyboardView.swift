import SwiftUI
import PianoTutorCore

/// Positions of the 61 keys (C2 to C7) inside a rectangle.
struct KeyboardGeometry {
    let size: CGSize
    let whiteNotes: [Int]
    let whiteWidth: CGFloat

    /// How many white keys lie below each pitch class within one octave.
    private static let whitesBelow: [Int] = [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6]

    init(size: CGSize) {
        self.size = size
        var whites: [Int] = []
        for midi in KeyboardRange.lowest...KeyboardRange.highest where !KeyboardRange.isBlack(midi) {
            whites.append(midi)
        }
        self.whiteNotes = whites
        self.whiteWidth = size.width / CGFloat(max(whites.count, 1))
    }

    var blackWidth: CGFloat { return whiteWidth * 0.62 }
    var blackHeight: CGFloat { return size.height * 0.62 }

    private func whiteIndex(_ midi: Int) -> Int {
        let relative: Int = midi - KeyboardRange.lowest
        let octave: Int = relative / 12
        let pitchClass: Int = relative % 12
        return octave * 7 + KeyboardGeometry.whitesBelow[pitchClass]
    }

    func rect(for midi: Int) -> CGRect {
        let index: CGFloat = CGFloat(whiteIndex(midi))
        if KeyboardRange.isBlack(midi) {
            return CGRect(x: index * whiteWidth - blackWidth / 2, y: 0, width: blackWidth, height: blackHeight)
        }
        return CGRect(x: index * whiteWidth, y: 0, width: whiteWidth, height: size.height)
    }

    func key(at point: CGPoint) -> Int? {
        if point.x < 0 || point.x >= size.width || point.y < 0 || point.y > size.height { return nil }
        if point.y <= blackHeight {
            for midi in KeyboardRange.lowest...KeyboardRange.highest where KeyboardRange.isBlack(midi) {
                if rect(for: midi).contains(point) { return midi }
            }
        }
        let index: Int = min(max(Int(point.x / whiteWidth), 0), whiteNotes.count - 1)
        return whiteNotes[index]
    }
}

/// The on-screen keyboard. It mirrors what is played, lights up the next keys and can be clicked.
struct KeyboardView: View {
    var held: Set<Int> = []
    var targets: [Int: KeyTarget] = [:]
    var good: Set<Int> = []
    var wrong: Set<Int> = []
    var marks: [KeyMark] = []
    var onPress: (Int) -> Void = { _ in }
    var onRelease: (Int) -> Void = { _ in }

    @State private var mouseNote: Int? = nil

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                draw(context, KeyboardGeometry(size: size))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        mouseMoved(to: KeyboardGeometry(size: proxy.size).key(at: value.location))
                    }
                    .onEnded { _ in
                        mouseMoved(to: nil)
                    }
            )
        }
    }

    private func mouseMoved(to note: Int?) {
        if note == mouseNote { return }
        if let old = mouseNote {
            onRelease(old)
        }
        mouseNote = note
        if let new = note {
            onPress(new)
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
        return mark(for: midi)?.label
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
        for midi in KeyboardRange.lowest...KeyboardRange.highest where KeyboardRange.isBlack(midi) {
            let rect: CGRect = geometry.rect(for: midi)
            let path = Path(roundedRect: rect, cornerRadius: min(3, whiteWidth * 0.12))
            context.fill(path, with: .color(fillColor(midi, black: true)))
            if isHighlighted(midi) {
                context.stroke(path, with: .color(Color.black.opacity(0.5)), lineWidth: 1)
            }
        }

        // Labels
        let fontSize: CGFloat = min(max(whiteWidth * 0.5, 9), 15)
        for midi in KeyboardRange.lowest...KeyboardRange.highest {
            let rect: CGRect = geometry.rect(for: midi)
            let black: Bool = KeyboardRange.isBlack(midi)
            let baseY: CGFloat = black ? rect.maxY - fontSize * 0.95 : size.height - fontSize * 1.0

            if let text = label(for: midi) {
                let long: Bool = text.count > 2
                let drawn = Text(text)
                    .font(.system(size: long ? fontSize * 0.8 : fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(labelColor(for: midi))
                context.draw(drawn, at: CGPoint(x: rect.midX, y: baseY))
            } else if !black && midi % 12 == 0 && !isHighlighted(midi) {
                // Name every C; Middle C gets a dot as a landmark.
                let octave: Int = midi / 12 - 1
                let name = Text("C" + String(octave))
                    .font(.system(size: fontSize * 0.72, weight: .medium, design: .rounded))
                    .foregroundColor(Color(white: 0.45))
                context.draw(name, at: CGPoint(x: rect.midX, y: baseY))
                if midi == 60 {
                    let dot = CGRect(x: rect.midX - 2.5, y: baseY - fontSize * 1.1, width: 5, height: 5)
                    context.fill(Path(ellipseIn: dot), with: .color(Theme.accent))
                }
            }
        }
    }
}

/// The keyboard as it appears at the bottom of every screen, wired to the shared input.
struct KeyboardPanel: View {
    @EnvironmentObject var input: InputHub
    var targets: [Int: KeyTarget] = [:]
    var good: Set<Int> = []
    var wrong: Set<Int> = []
    var marks: [KeyMark] = []

    var body: some View {
        KeyboardView(
            held: input.held,
            targets: targets,
            good: good,
            wrong: wrong,
            marks: marks,
            onPress: { midi in input.press(midi, source: .mouse) },
            onRelease: { midi in input.release(midi, source: .mouse) }
        )
        .frame(height: 150)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Theme.panel)
    }
}

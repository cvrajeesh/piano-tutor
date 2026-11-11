import SwiftUI
import CoreText
import PianoTutorCore

/// Loads the Bravura music font (SIL Open Font License) that provides clefs, rests and accidentals.
enum MusicFont {
    static let isAvailable: Bool = register()

    /// A fixed size: the glyphs must match the staff, which does not follow Dynamic Type.
    static func font(size: CGFloat) -> Font {
        return Font.custom("Bravura", fixedSize: size)
    }

    private static func register() -> Bool {
        var candidates: [URL] = []
        if let bundled = Bundle.main.url(forResource: "Bravura", withExtension: "otf") {
            candidates.append(bundled)
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("Bravura.otf"))
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Bravura.otf"))
        // When run straight from the package (swift run, or Xcode), fall back to the source tree.
        let sourceFile = URL(fileURLWithPath: #filePath)
        candidates.append(sourceFile.deletingLastPathComponent().appendingPathComponent("Resources/Bravura.otf"))

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) {
                return true
            }
        }
        return false
    }

    // SMuFL code points
    static let gClef = "\u{E050}"
    static let fClef = "\u{E062}"
    static let restWhole = "\u{E4E3}"
    static let restHalf = "\u{E4E4}"
    static let restQuarter = "\u{E4E5}"
    static let restEighth = "\u{E4E6}"
    static let flagUp = "\u{E240}"
    static let flagDown = "\u{E241}"
    static let flat = "\u{E260}"
    static let natural = "\u{E261}"
    static let sharp = "\u{E262}"

    private static let timeDigits: [String] = [
        "\u{E080}", "\u{E081}", "\u{E082}", "\u{E083}", "\u{E084}",
        "\u{E085}", "\u{E086}", "\u{E087}", "\u{E088}", "\u{E089}",
    ]

    static func timeDigit(_ digit: Int) -> String {
        return timeDigits[min(max(digit, 0), 9)]
    }
}

/// A staff whose notes scroll from right to left past a fixed playhead.
struct StaffView: View {
    let layout: StaffLayout
    let source: StaffSource
    var showNoteNames: Bool = true
    var showPlayhead: Bool = true
    var animated: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !animated)) { timeline in
            Canvas { context, size in
                _ = timeline.date
                let renderer = StaffRenderer(
                    layout: layout,
                    source: source,
                    showNoteNames: showNoteNames,
                    showPlayhead: showPlayhead,
                    size: size
                )
                renderer.draw(in: context, now: HostClock.now)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Music staff")
        .accessibilityValue(showPlayhead ? "" : spokenNotes)
        .accessibilityAddTraits(.isImage)
    }

    /// The notes in order, for a staff that stands still (an example in a lesson, or Free Play).
    /// A scrolling exercise is left out: it is too long to read, and the keyboard says what to play next.
    private var spokenNotes: String {
        let notes: [NoteEvent] = layout.score.notes.sorted { $0.start < $1.start }
        if notes.isEmpty { return String(localized: "No notes", comment: "VoiceOver: an empty staff") }
        // A chord is a list joined with "and"; the notes one after another are separated as
        // the language separates items ("C4, D4, E4", "ド4、レ4、ミ4").
        let spoken: [String] = notes.map { note in
            Announcer.list(note.pitches.map { $0.midi }.sorted().map { Announcer.spokenName(ofKey: $0) })
        }
        return spoken.formatted(.list(type: .and, width: .narrow))
    }
}

private enum GlyphAlign {
    case leading
    case center
    case trailing
}

struct StaffRenderer {
    let layout: StaffLayout
    let source: StaffSource
    let showNoteNames: Bool
    let showPlayhead: Bool
    let size: CGSize

    /// One staff space (the distance between two staff lines).
    let sp: CGFloat
    let bottomLines: [Clef: CGFloat]
    let headerWidth: CGFloat
    let playheadX: CGFloat
    let pxPerBeat: CGFloat
    let barOffset: CGFloat
    let useMusicFont: Bool

    init(layout: StaffLayout, source: StaffSource, showNoteNames: Bool, showPlayhead: Bool, size: CGSize) {
        self.layout = layout
        self.source = source
        self.showNoteNames = showNoteNames
        self.showPlayhead = showPlayhead
        self.size = size

        let twoStaves: Bool = layout.clefs.count > 1
        let neededSpaces: CGFloat = twoStaves ? 27 : 15
        // On a narrow screen the staff also shrinks with the width, so that a few beats stay in view.
        let widthLimit: CGFloat = max(size.width / 45, 6)
        let space: CGFloat = min(max(size.height / neededSpaces, 6), 17, widthLimit)
        self.sp = space

        var lines: [Clef: CGFloat] = [:]
        if twoStaves {
            // Treble staff (4 spaces), a gap of 7 spaces, then the bass staff.
            let top: CGFloat = (size.height - 15 * space) / 2
            lines[layout.clefs[0]] = top + 4 * space
            lines[layout.clefs[1]] = top + 15 * space
        } else if let only = layout.clefs.first {
            let top: CGFloat = (size.height - 4 * space) / 2
            lines[only] = top + 4 * space
        }
        self.bottomLines = lines

        let keyCount: CGFloat = CGFloat(abs(layout.score.keySignature))
        self.headerWidth = space * (6.8 + keyCount)
        self.playheadX = space * (6.8 + keyCount) + space * 2.6
        self.pxPerBeat = space * 7
        self.barOffset = space * 1.7
        self.useMusicFont = MusicFont.isAvailable
    }

    // MARK: Geometry

    private func y(_ clef: Clef, _ position: Int) -> CGFloat {
        let base: CGFloat = bottomLines[clef] ?? 0
        return base - CGFloat(position) * sp / 2
    }

    private func x(_ beat: Double, _ viewBeat: Double) -> CGFloat {
        return playheadX + CGFloat(beat - viewBeat) * pxPerBeat
    }

    private func isVisible(_ x: CGFloat) -> Bool {
        return x > headerWidth - 4 * sp && x < size.width + 4 * sp
    }

    /// Notes fade as they slide past the playhead towards the clef.
    private func fade(_ x: CGFloat) -> Double {
        if x >= playheadX { return 1 }
        let span: CGFloat = max(playheadX - headerWidth, 1)
        let fraction: CGFloat = (x - headerWidth) / span
        return Double(min(max(fraction, 0), 1)) * 0.8
    }

    private func color(for visual: NoteVisual, hand: Hand) -> Color {
        switch visual {
        case .upcoming: return Theme.ink
        case .active: return Theme.hand(hand)
        case .hit: return Theme.good
        case .missed: return Theme.bad
        case .passive: return Theme.ink.opacity(0.38)
        }
    }

    // MARK: Drawing

    func draw(in context: GraphicsContext, now: TimeInterval) {
        guard !layout.clefs.isEmpty else { return }
        let viewBeat: Double = source.viewBeat(at: now)

        drawStaffLines(context)

        var scroll = context
        let clipRect = CGRect(x: headerWidth, y: 0, width: max(size.width - headerWidth, 0), height: size.height)
        scroll.clip(to: Path(clipRect))
        drawBarlines(scroll, viewBeat)
        let tips: [Int: CGFloat] = drawBeams(scroll, viewBeat)
        drawNotes(scroll, viewBeat, tips)
        drawRests(scroll, viewBeat)

        drawHeader(context)
        if showPlayhead {
            drawPlayhead(context)
        }
        drawOverlay(context, source.overlay(at: now))
    }

    private func drawStaffLines(_ context: GraphicsContext) {
        let lineWidth: CGFloat = max(1, sp * 0.1)
        for clef in layout.clefs {
            for line in 0..<5 {
                let lineY: CGFloat = y(clef, line * 2)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: lineY))
                path.addLine(to: CGPoint(x: size.width, y: lineY))
                context.stroke(path, with: .color(Theme.ink.opacity(0.5)), lineWidth: lineWidth)
            }
        }
    }

    private var topY: CGFloat {
        guard let first = layout.clefs.first else { return 0 }
        return y(first, 8)
    }

    private var bottomY: CGFloat {
        guard let last = layout.clefs.last else { return size.height }
        return y(last, 0)
    }

    private func drawBarlines(_ context: GraphicsContext, _ viewBeat: Double) {
        let lineWidth: CGFloat = max(1, sp * 0.14)
        for beat in layout.score.barlines {
            let barX: CGFloat = x(beat, viewBeat) - barOffset
            if !isVisible(barX) { continue }
            var path = Path()
            path.move(to: CGPoint(x: barX, y: topY))
            path.addLine(to: CGPoint(x: barX, y: bottomY))
            context.stroke(path, with: .color(Theme.ink.opacity(0.5 * fade(barX) + 0.1)), lineWidth: lineWidth)
        }

        // Final double barline.
        let endX: CGFloat = x(layout.score.totalBeats, viewBeat) - barOffset
        if isVisible(endX) {
            var thin = Path()
            thin.move(to: CGPoint(x: endX, y: topY))
            thin.addLine(to: CGPoint(x: endX, y: bottomY))
            context.stroke(thin, with: .color(Theme.ink.opacity(0.7)), lineWidth: lineWidth)
            let thick = CGRect(x: endX + sp * 0.45, y: topY, width: sp * 0.5, height: bottomY - topY)
            context.fill(Path(thick), with: .color(Theme.ink.opacity(0.7)))
        }
    }

    private func stem(for note: LaidNote, at noteX: CGFloat) -> (x: CGFloat, start: CGFloat, tip: CGFloat)? {
        if note.shape.value == .whole { return nil }
        guard let low = note.heads.first, let high = note.heads.last else { return nil }
        let lowY: CGFloat = y(note.clef, low.position)
        let highY: CGFloat = y(note.clef, high.position)
        if note.stemUp {
            return (noteX + sp * 0.56, lowY - sp * 0.12, highY - sp * 3.4)
        }
        return (noteX - sp * 0.56, highY + sp * 0.12, lowY + sp * 3.4)
    }

    /// Draws the beams and returns the adjusted stem tips, keyed by note index.
    private func drawBeams(_ context: GraphicsContext, _ viewBeat: Double) -> [Int: CGFloat] {
        var tips: [Int: CGFloat] = [:]
        for group in layout.beams {
            guard group.noteIndices.count == 2 else { continue }
            let first: LaidNote = layout.notes[group.noteIndices[0]]
            let second: LaidNote = layout.notes[group.noteIndices[1]]
            guard bottomLines[first.clef] != nil else { continue }
            let firstX: CGFloat = x(first.start, viewBeat)
            let secondX: CGFloat = x(second.start, viewBeat)
            guard let stemA = stem(for: first, at: firstX), let stemB = stem(for: second, at: secondX) else { continue }

            // Keep the beam nearly flat: at most one staff space of slope.
            let delta: CGFloat = min(max(stemB.tip - stemA.tip, -sp), sp)
            let tipA: CGFloat
            let tipB: CGFloat
            if group.stemUp {
                let base: CGFloat = min(stemA.tip, stemB.tip)
                if delta >= 0 {
                    tipA = base
                    tipB = base + delta
                } else {
                    tipB = base
                    tipA = base - delta
                }
            } else {
                let base: CGFloat = max(stemA.tip, stemB.tip)
                if delta >= 0 {
                    tipB = base
                    tipA = base - delta
                } else {
                    tipA = base
                    tipB = base + delta
                }
            }
            tips[first.index] = tipA
            tips[second.index] = tipB

            if !isVisible(firstX) && !isVisible(secondX) { continue }
            let thickness: CGFloat = sp * 0.5 * (group.stemUp ? 1 : -1)
            var beam = Path()
            beam.move(to: CGPoint(x: stemA.x, y: tipA))
            beam.addLine(to: CGPoint(x: stemB.x, y: tipB))
            beam.addLine(to: CGPoint(x: stemB.x, y: tipB + thickness))
            beam.addLine(to: CGPoint(x: stemA.x, y: tipA + thickness))
            beam.closeSubpath()
            let visual: NoteVisual = source.visual(forEvent: first.eventID)
            let beamColor: Color = color(for: visual, hand: first.hand)
            var layer = context
            layer.opacity = fade(firstX)
            layer.fill(beam, with: .color(beamColor))
        }
        return tips
    }

    private func drawNotes(_ context: GraphicsContext, _ viewBeat: Double, _ tips: [Int: CGFloat]) {
        for note in layout.notes {
            guard bottomLines[note.clef] != nil else { continue }
            let noteX: CGFloat = x(note.start, viewBeat)

            if note.tieToNext {
                drawTie(context, from: note, at: noteX, viewBeat: viewBeat)
            }
            if !isVisible(noteX) { continue }

            let visual: NoteVisual = source.visual(forEvent: note.eventID)
            let noteColor: Color = color(for: visual, hand: note.hand)
            var layer = context
            layer.opacity = fade(noteX)
            drawNote(layer, note, at: noteX, color: noteColor, tip: tips[note.index])
        }
    }

    private func drawNote(_ context: GraphicsContext, _ note: LaidNote, at noteX: CGFloat, color noteColor: Color, tip: CGFloat?) {
        let lineWidth: CGFloat = max(1, sp * 0.13)

        // Stem first, so the heads sit on top of it.
        if let geometry = stem(for: note, at: noteX) {
            let tipY: CGFloat = tip ?? geometry.tip
            var path = Path()
            path.move(to: CGPoint(x: geometry.x, y: geometry.start))
            path.addLine(to: CGPoint(x: geometry.x, y: tipY))
            context.stroke(path, with: .color(noteColor), lineWidth: lineWidth)

            if note.shape.value == .eighth && note.beamGroup == nil {
                if useMusicFont {
                    let flag: String = note.stemUp ? MusicFont.flagUp : MusicFont.flagDown
                    glyph(context, flag, x: geometry.x - lineWidth / 2, y: tipY, color: noteColor, align: .leading)
                } else {
                    let direction: CGFloat = note.stemUp ? 1 : -1
                    var flagPath = Path()
                    flagPath.move(to: CGPoint(x: geometry.x, y: tipY))
                    flagPath.addQuadCurve(
                        to: CGPoint(x: geometry.x + sp * 0.9, y: tipY + direction * sp * 2.2),
                        control: CGPoint(x: geometry.x + sp * 1.2, y: tipY + direction * sp * 0.9)
                    )
                    context.stroke(flagPath, with: .color(noteColor), lineWidth: lineWidth * 1.6)
                }
            }
        }

        for head in note.heads {
            let headY: CGFloat = y(note.clef, head.position)
            let center = CGPoint(x: noteX, y: headY)

            drawLedgerLines(context, clef: note.clef, position: head.position, at: noteX, color: noteColor)
            drawHead(context, center: center, value: note.shape.value, color: noteColor, label: showNoteNames ? NoteNaming.current.headLabel(head.pitch) : nil)

            if let accidental = head.accidental {
                drawAccidental(context, accidental, x: noteX - sp * 0.95, y: headY, color: noteColor)
            }

            if note.shape.dotted {
                let onLine: Bool = head.position % 2 == 0
                let dotY: CGFloat = onLine ? headY - sp * 0.5 : headY
                let dot = CGRect(x: noteX + sp * 1.0, y: dotY - sp * 0.2, width: sp * 0.4, height: sp * 0.4)
                context.fill(Path(ellipseIn: dot), with: .color(noteColor))
            }
        }
    }

    private func drawLedgerLines(_ context: GraphicsContext, clef: Clef, position: Int, at noteX: CGFloat, color lineColor: Color) {
        var positions: [Int] = []
        if position <= -2 {
            var p: Int = -2
            while p >= position {
                positions.append(p)
                p -= 2
            }
        } else if position >= 10 {
            var p: Int = 10
            while p <= position {
                positions.append(p)
                p += 2
            }
        }
        for p in positions {
            let lineY: CGFloat = y(clef, p)
            var path = Path()
            path.move(to: CGPoint(x: noteX - sp * 1.0, y: lineY))
            path.addLine(to: CGPoint(x: noteX + sp * 1.0, y: lineY))
            context.stroke(path, with: .color(lineColor.opacity(0.8)), lineWidth: max(1, sp * 0.13))
        }
    }

    private func ellipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, rotation: CGFloat) -> Path {
        let rect = CGRect(x: -radiusX, y: -radiusY, width: radiusX * 2, height: radiusY * 2)
        let rotated: Path = Path(ellipseIn: rect).applying(CGAffineTransform(rotationAngle: rotation))
        return rotated.applying(CGAffineTransform(translationX: center.x, y: center.y))
    }

    private func drawHead(_ context: GraphicsContext, center: CGPoint, value: NoteValue, color headColor: Color, label: String?) {
        let labelled: Bool = label != nil
        // Heads are drawn a little larger when they carry a letter.
        let scale: CGFloat = labelled ? 1.12 : 1.0
        var labelColor: Color = Theme.paper

        switch value {
        case .quarter, .eighth:
            let head: Path = ellipse(center: center, radiusX: sp * 0.62 * scale, radiusY: sp * 0.44 * scale, rotation: -0.35)
            context.fill(head, with: .color(headColor))
        case .half:
            var head: Path = ellipse(center: center, radiusX: sp * 0.62 * scale, radiusY: sp * 0.44 * scale, rotation: -0.35)
            let holeY: CGFloat = labelled ? 0.31 : 0.2
            head.addPath(ellipse(center: center, radiusX: sp * 0.47 * scale, radiusY: sp * holeY * scale, rotation: -0.5))
            context.fill(head, with: .color(headColor), style: FillStyle(eoFill: true))
            labelColor = headColor
        case .whole:
            var head: Path = ellipse(center: center, radiusX: sp * 0.78 * scale, radiusY: sp * 0.46 * scale, rotation: 0)
            let holeX: CGFloat = labelled ? 0.5 : 0.36
            head.addPath(ellipse(center: center, radiusX: sp * holeX * scale, radiusY: sp * 0.31 * scale, rotation: labelled ? 0 : 0.6))
            context.fill(head, with: .color(headColor), style: FillStyle(eoFill: true))
            labelColor = headColor
        }

        if let label = label {
            // A letter fills the head; a longer name such as Sol or ファ is drawn smaller to fit.
            let width: CGFloat = sp * (value == .whole ? 1.3 : 1.05) * scale
            context.drawFitted(at: center, size: sp * 0.74, maxWidth: width, minimumScale: 0.5) { size in
                Text(verbatim: label)
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundColor(labelColor)
            }
        }
    }

    private func drawAccidental(_ context: GraphicsContext, _ accidental: Int, x rightEdge: CGFloat, y centerY: CGFloat, color accidentalColor: Color) {
        if useMusicFont {
            let symbol: String = accidental > 0 ? MusicFont.sharp : (accidental < 0 ? MusicFont.flat : MusicFont.natural)
            glyph(context, symbol, x: rightEdge, y: centerY, color: accidentalColor, align: .trailing)
        } else {
            let symbol: String = accidental > 0 ? "♯" : (accidental < 0 ? "♭" : "♮")
            let text = Text(symbol).font(.system(size: sp * 2.0)).foregroundColor(accidentalColor)
            context.draw(text, at: CGPoint(x: rightEdge - sp * 0.5, y: centerY))
        }
    }

    private func drawTie(_ context: GraphicsContext, from note: LaidNote, at noteX: CGFloat, viewBeat: Double) {
        let nextIndex: Int = note.index + 1
        guard nextIndex < layout.notes.count else { return }
        let next: LaidNote = layout.notes[nextIndex]
        guard next.eventID == note.eventID else { return }
        let nextX: CGFloat = x(next.start, viewBeat)
        if !isVisible(noteX) && !isVisible(nextX) { return }

        let visual: NoteVisual = source.visual(forEvent: note.eventID)
        let tieColor: Color = color(for: visual, hand: note.hand)
        let direction: CGFloat = note.stemUp ? 1 : -1
        for head in note.heads {
            let headY: CGFloat = y(note.clef, head.position) + direction * sp * 0.7
            var path = Path()
            path.move(to: CGPoint(x: noteX + sp * 0.75, y: headY))
            path.addQuadCurve(
                to: CGPoint(x: nextX - sp * 0.75, y: headY),
                control: CGPoint(x: (noteX + nextX) / 2, y: headY + direction * sp * 1.1)
            )
            var layer = context
            layer.opacity = fade(nextX)
            layer.stroke(path, with: .color(tieColor), lineWidth: max(1, sp * 0.16))
        }
    }

    private func drawRests(_ context: GraphicsContext, _ viewBeat: Double) {
        for rest in layout.rests {
            guard bottomLines[rest.clef] != nil else { continue }
            var restX: CGFloat = x(rest.start, viewBeat)
            if rest.fillsMeasure {
                restX = x(rest.start + rest.duration / 2, viewBeat) - barOffset / 2
            }
            if !isVisible(restX) { continue }

            var layer = context
            layer.opacity = fade(restX) * 0.85
            let restColor: Color = Theme.ink

            if useMusicFont {
                let symbol: String
                let position: Int
                switch rest.shape.value {
                case .whole:
                    symbol = MusicFont.restWhole
                    position = 6
                case .half:
                    symbol = MusicFont.restHalf
                    position = 4
                case .quarter:
                    symbol = MusicFont.restQuarter
                    position = 4
                case .eighth:
                    symbol = MusicFont.restEighth
                    position = 4
                }
                glyph(layer, symbol, x: restX, y: y(rest.clef, position), color: restColor, align: .center)
            } else {
                // Without the music font, draw simple blocks.
                let middle: CGFloat = y(rest.clef, 4)
                let block: CGRect
                switch rest.shape.value {
                case .whole: block = CGRect(x: restX - sp * 0.6, y: y(rest.clef, 6), width: sp * 1.2, height: sp * 0.5)
                case .half: block = CGRect(x: restX - sp * 0.6, y: middle - sp * 0.5, width: sp * 1.2, height: sp * 0.5)
                case .quarter: block = CGRect(x: restX - sp * 0.15, y: middle - sp * 1.2, width: sp * 0.3, height: sp * 2.4)
                case .eighth: block = CGRect(x: restX - sp * 0.15, y: middle - sp * 0.7, width: sp * 0.3, height: sp * 1.4)
                }
                layer.fill(Path(block), with: .color(restColor))
            }

            if rest.shape.dotted {
                let dot = CGRect(x: restX + sp * 0.9, y: y(rest.clef, 5) - sp * 0.2, width: sp * 0.4, height: sp * 0.4)
                layer.fill(Path(ellipseIn: dot), with: .color(restColor))
            }
        }
    }

    private func drawHeader(_ context: GraphicsContext) {
        let score: Score = layout.score

        if layout.clefs.count > 1 {
            // The line that joins the two staves into one system.
            let join = CGRect(x: sp * 0.35, y: topY, width: max(1.5, sp * 0.18), height: bottomY - topY)
            context.fill(Path(join), with: .color(Theme.ink.opacity(0.75)))
        }

        for clef in layout.clefs {
            if useMusicFont {
                switch clef {
                case .treble:
                    glyph(context, MusicFont.gClef, x: sp * 1.0, y: y(clef, 2), color: Theme.ink, align: .leading)
                case .bass:
                    glyph(context, MusicFont.fClef, x: sp * 1.0, y: y(clef, 6), color: Theme.ink, align: .leading)
                }
            } else {
                let name: String = clef == .treble ? "𝄞" : "𝄢"
                let text = Text(name).font(.system(size: sp * 5)).foregroundColor(Theme.ink)
                context.draw(text, at: CGPoint(x: sp * 2.3, y: y(clef, 4)))
            }

            // Key signature
            let positions: [Int] = StaffLayout.keySignaturePositions(score.keySignature, clef: clef)
            for (index, position) in positions.enumerated() {
                let symbolX: CGFloat = sp * (4.1 + CGFloat(index) * 1.0)
                if useMusicFont {
                    let symbol: String = score.keySignature > 0 ? MusicFont.sharp : MusicFont.flat
                    glyph(context, symbol, x: symbolX, y: y(clef, position), color: Theme.ink, align: .leading)
                } else {
                    let symbol: String = score.keySignature > 0 ? "♯" : "♭"
                    let text = Text(symbol).font(.system(size: sp * 2.0)).foregroundColor(Theme.ink)
                    context.draw(text, at: CGPoint(x: symbolX + sp * 0.5, y: y(clef, position)))
                }
            }

            // Time signature
            let timeX: CGFloat = sp * (5.4 + CGFloat(positions.count) * 1.0)
            if useMusicFont {
                glyph(context, MusicFont.timeDigit(score.time.beats), x: timeX, y: y(clef, 6), color: Theme.ink, align: .center)
                glyph(context, MusicFont.timeDigit(score.time.unit), x: timeX, y: y(clef, 2), color: Theme.ink, align: .center)
            } else {
                let top = Text(String(score.time.beats)).font(.system(size: sp * 2.2, weight: .bold, design: .serif)).foregroundColor(Theme.ink)
                let bottom = Text(String(score.time.unit)).font(.system(size: sp * 2.2, weight: .bold, design: .serif)).foregroundColor(Theme.ink)
                context.draw(top, at: CGPoint(x: timeX, y: y(clef, 6)))
                context.draw(bottom, at: CGPoint(x: timeX, y: y(clef, 2)))
            }
        }
    }

    private func drawPlayhead(_ context: GraphicsContext) {
        let top: CGFloat = topY - sp * 1.6
        let bottom: CGFloat = bottomY + sp * 1.6
        let band = CGRect(x: playheadX - sp * 0.9, y: top, width: sp * 1.8, height: bottom - top)
        context.fill(Path(roundedRect: band, cornerRadius: sp * 0.5), with: .color(Theme.accent.opacity(0.16)))
        var line = Path()
        line.move(to: CGPoint(x: playheadX, y: top))
        line.addLine(to: CGPoint(x: playheadX, y: bottom))
        context.stroke(line, with: .color(Theme.accent.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawOverlay(_ context: GraphicsContext, _ overlay: StaffOverlay) {
        if let count = overlay.countIn {
            let text = Text(String(count))
                .font(.system(size: sp * 5, weight: .bold, design: .rounded))
                .foregroundColor(Theme.accent)
            let center = CGPoint(x: (playheadX + size.width) / 2, y: max(topY - sp * 3.2, sp * 3))
            context.draw(text, at: center)
        }
        if let message = overlay.feedbackText {
            let progress: Double = min(max(overlay.feedbackAge / 0.8, 0), 1)
            let text = Text(message)
                .font(.system(size: max(sp * 1.15, 13), weight: .bold, design: .rounded))
                .foregroundColor(overlay.feedbackColor)
            var layer = context
            layer.opacity = 1 - progress * progress
            let rise: CGFloat = CGFloat(progress) * sp * 1.2
            layer.draw(text, at: CGPoint(x: playheadX + sp * 3.5, y: max(topY - sp * 2.4 - rise, sp)))
        }
    }

    /// Draws a music-font glyph with its SMuFL origin (on the baseline) at the given point.
    private func glyph(_ context: GraphicsContext, _ symbol: String, x: CGFloat, y: CGFloat, color glyphColor: Color, align: GlyphAlign) {
        let text = Text(symbol).font(MusicFont.font(size: sp * 4)).foregroundColor(glyphColor)
        let resolved = context.resolve(text)
        let bounds = CGSize(width: 2000, height: 2000)
        let measured: CGSize = resolved.measure(in: bounds)
        let baseline: CGFloat = resolved.firstBaseline(in: bounds)
        var originX: CGFloat = x
        switch align {
        case .leading: break
        case .center: originX = x - measured.width / 2
        case .trailing: originX = x - measured.width
        }
        context.draw(resolved, at: CGPoint(x: originX, y: y - baseline), anchor: .topLeading)
    }
}

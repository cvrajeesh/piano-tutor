import SwiftUI
import PianoTutorCore

/// Play anything and see what it is called and where it sits on the staff.
struct FreePlayView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var input: InputHub
    @Environment(\.screenLayout) private var screen

    @State private var source = StaticStaffSource(beat: -1.2)

    private var heldPitches: [Pitch] {
        return input.held.sorted().map { Pitch.fromMIDI($0) }
    }

    /// The held notes as one chord per hand: Middle C and above on the treble staff.
    private var layout: StaffLayout {
        var notes: [NoteEvent] = []
        let pitches: [Pitch] = heldPitches
        let upper: [Pitch] = pitches.filter { $0.midi >= 60 }
        let lower: [Pitch] = pitches.filter { $0.midi < 60 }
        for (hand, group) in [(Hand.right, upper), (Hand.left, lower)] where !group.isEmpty {
            notes.append(NoteEvent(
                id: notes.count,
                hand: hand,
                start: 0,
                duration: 4,
                pitches: group,
                fingers: Array(repeating: nil, count: group.count),
                segments: [NoteSegment(start: 0, duration: 4)]
            ))
        }
        let score = Score(time: .common, tempo: 80, keySignature: 0, pickup: 0, notes: notes, rests: [], totalBeats: 4)
        return StaffLayout(score: score, staves: [.treble, .bass])
    }

    var body: some View {
        VStack(spacing: 0) {
            if !screen.short {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Free Play")
                        .scaledFont(30, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Play anything. The notes you hold appear on the staff with their names.")
                        .scaledFont(14)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, screen.compact ? 16 : 32)
                .padding(.top, screen.compact ? 16 : 32)
                .padding(.bottom, 16)
            }

            GeometryReader { proxy in
                let namesWidth: CGFloat = screen.short ? 200 : 280
                // Side by side only leaves a usable staff when there is width to spare.
                if proxy.size.height > proxy.size.width || proxy.size.width < namesWidth + 300 {
                    // Upright iPhone or iPad: names above the staff.
                    VStack(spacing: 12) {
                        names
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .background(Theme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        staff
                    }
                } else {
                    HStack(spacing: screen.short ? 10 : 18) {
                        staff
                        names
                            .frame(width: namesWidth)
                            .frame(maxHeight: .infinity)
                            .background(Theme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, screen.compact ? 10 : 32)
            .padding(.top, screen.short ? 8 : 0)
            .padding(.bottom, screen.compact ? 8 : 18)

            KeyboardPanel()
        }
        .playingScreenTextLimit()
    }

    private var staff: some View {
        StaffView(layout: layout, source: source, showNoteNames: true, showPlayhead: false, animated: false)
            .background(Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var names: some View {
        VStack(spacing: screen.compact ? 6 : 10) {
            Text(verbatim: heldPitches.isEmpty ? "–" : heldPitches.map { NoteNaming.current.name($0) }.joined(separator: "  "))
                .scaledFont(screen.compact ? 32 : 40, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            fullNames
                .scaledFont(13)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            #if os(macOS)
            if !model.midi.isConnected {
                Text(computerKeysHelp)
                    .scaledFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
            #endif
        }
        .padding(screen.compact ? 12 : 20)
    }

    private var fullNames: Text {
        if heldPitches.isEmpty {
            return Text("Press a key")
        }
        return Text(verbatim: heldPitches.map { NoteNaming.current.fullName($0) }.joined(separator: " "))
    }

    #if os(macOS)
    /// Which computer keys play which notes, with the letters of the user's keyboard layout.
    private var computerKeysHelp: String {
        let white: String = ComputerKeyboard.labels(ComputerKeyboard.whiteKeys)
        let black: String = ComputerKeyboard.labels(ComputerKeyboard.blackKeys)
        let down: String = ComputerKeyboard.label(ComputerKeyboard.octaveDown)
        let up: String = ComputerKeyboard.label(ComputerKeyboard.octaveUp)
        if input.octaveShift == 0 {
            return String(localized: "Computer keys: \(white) play the white keys from Middle C, \(black) the black keys. \(down) and \(up) shift the octave.", comment: "The placeholders are letters on computer keys in the user's keyboard layout, such as A S D F G H J K")
        }
        let shift: String = input.octaveShift.formatted(.number.sign(strategy: .always()))
        return String(localized: "Computer keys: \(white) play the white keys from Middle C, \(black) the black keys. \(down) and \(up) shift the octave (now \(shift)).", comment: "The placeholders are letters on computer keys in the user's keyboard layout, such as A S D F G H J K. The last one is the octave shift, such as +1 or -2")
    }
    #endif
}

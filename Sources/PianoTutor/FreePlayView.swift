import SwiftUI
import PianoTutorCore

/// Play anything and see what it is called and where it sits on the staff.
struct FreePlayView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var input: InputHub

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
            VStack(alignment: .leading, spacing: 6) {
                Text("Free Play")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text("Play anything. The notes you hold appear on the staff with their names.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 16)

            HStack(spacing: 18) {
                StaffView(layout: layout, source: source, showNoteNames: true, showPlayhead: false, animated: false)
                    .background(Theme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 10) {
                    Text(heldPitches.isEmpty ? "–" : heldPitches.map { $0.name }.joined(separator: "  "))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Text(heldPitches.isEmpty ? "Press a key" : heldPitches.map { $0.fullName }.joined(separator: " "))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                    if !model.midi.isConnected {
                        Text("Computer keys: A S D F G H J K play the white keys from Middle C, W E T Y U the black keys. Z and X shift the octave" + octaveNote + ".")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                    }
                }
                .padding(20)
                .frame(width: 280)
                .frame(maxHeight: .infinity)
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 18)

            KeyboardPanel()
        }
    }

    private var octaveNote: String {
        if input.octaveShift == 0 { return "" }
        let sign: String = input.octaveShift > 0 ? "+" : ""
        return " (now " + sign + String(input.octaveShift) + ")"
    }
}

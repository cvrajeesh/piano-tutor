import Foundation
#if os(macOS)
import AppKit
import Carbon.HIToolbox
#endif
import Combine

#if os(macOS)
/// The computer keys that stand in for piano keys, by position, and the letters printed on
/// them in the user's keyboard layout. On a US keyboard the white keys are A S D F G H J K;
/// on a French one the same keys read Q S D F G H J K.
enum ComputerKeyboard {
    /// From Middle C up to the C above it.
    static let whiteKeys: [UInt16] = [
        kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K,
    ].map { UInt16($0) }
    /// C♯, D♯, F♯, G♯ and A♯ above Middle C.
    static let blackKeys: [UInt16] = [kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_T, kVK_ANSI_Y, kVK_ANSI_U].map { UInt16($0) }
    static let octaveDown: UInt16 = UInt16(kVK_ANSI_Z)
    static let octaveUp: UInt16 = UInt16(kVK_ANSI_X)

    /// The letters on some keys in the current layout, separated by spaces: "A S D F".
    static func labels(_ codes: [UInt16]) -> String {
        return codes.map(label).joined(separator: " ")
    }

    /// The character on a key in the current layout, such as "A", or "Q" on AZERTY.
    static func label(_ code: UInt16) -> String {
        let fallback: [UInt16: String] = [
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K",
            UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_Y): "Y",
            UInt16(kVK_ANSI_U): "U", UInt16(kVK_ANSI_Z): "Z", UInt16(kVK_ANSI_X): "X",
        ]
        return typedCharacter(code)?.uppercased() ?? fallback[code] ?? "?"
    }

    private static func typedCharacter(_ code: UInt16) -> String? {
        // An input method (Japanese, Chinese, Korean) has no key layout of its own; the
        // ASCII-capable layout it types with does.
        var source: TISInputSource? = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        if source.flatMap({ TISGetInputSourceProperty($0, kTISPropertyUnicodeKeyLayoutData) }) == nil {
            source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
        }
        guard let layoutSource = source,
              let pointer = TISGetInputSourceProperty(layoutSource, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data: Data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var characters: [UniChar] = Array(repeating: 0, count: 4)
        var length: Int = 0
        let status: OSStatus = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return OSStatus(paramErr) }
            return UCKeyTranslate(
                layout, code, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        let text: String = String(utf16CodeUnits: characters, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
#endif

struct NoteInput {
    enum Kind {
        case on
        case off
    }

    enum Source {
        case midi
        case computerKeys
        /// A click or a touch on the on-screen keys.
        case mouse
        /// A piano heard through the microphone.
        case microphone
    }

    let kind: Kind
    let midi: Int
    let velocity: Int
    let time: TimeInterval
    let source: Source
}

/// Merges notes from the MIDI keyboard, the microphone, the on-screen keys and the computer keyboard into one stream.
final class InputHub: ObservableObject {
    @Published private(set) var held: Set<Int> = []
    @Published private(set) var octaveShift: Int = 0

    let events = PassthroughSubject<NoteInput, Never>()

    /// Called for every note before listeners, used to play the sound.
    var monitor: ((NoteInput) -> Void)?

    /// The notes the current exercise is waiting for. The microphone needs to know them to
    /// recognise chords; the other inputs ignore them.
    var expectedNotes: Set<Int> = [] {
        didSet {
            if expectedNotes != oldValue {
                onExpectedNotes?(expectedNotes)
            }
        }
    }
    var onExpectedNotes: ((Set<Int>) -> Void)?

    #if os(macOS)
    private var keyMonitor: Any?
    private var activeKeys: [UInt16: Int] = [:]

    /// Home-row keys play the white keys from Middle C; the row above plays the black keys.
    /// Keys are matched by their position, not the letter on them, so the piano row stays in
    /// the same place on AZERTY, QWERTZ and other layouts.
    private static let keyMap: [UInt16: Int] = [
        ComputerKeyboard.whiteKeys[0]: 60, ComputerKeyboard.blackKeys[0]: 61,
        ComputerKeyboard.whiteKeys[1]: 62, ComputerKeyboard.blackKeys[1]: 63,
        ComputerKeyboard.whiteKeys[2]: 64,
        ComputerKeyboard.whiteKeys[3]: 65, ComputerKeyboard.blackKeys[2]: 66,
        ComputerKeyboard.whiteKeys[4]: 67, ComputerKeyboard.blackKeys[3]: 68,
        ComputerKeyboard.whiteKeys[5]: 69, ComputerKeyboard.blackKeys[4]: 70,
        ComputerKeyboard.whiteKeys[6]: 71,
        ComputerKeyboard.whiteKeys[7]: 72, UInt16(kVK_ANSI_O): 73,
        UInt16(kVK_ANSI_L): 74, UInt16(kVK_ANSI_P): 75, UInt16(kVK_ANSI_Semicolon): 76,
    ]
    #endif

    /// Must be called on the main thread.
    func send(_ input: NoteInput) {
        switch input.kind {
        case .on:
            if !held.contains(input.midi) {
                held.insert(input.midi)
            }
        case .off:
            if held.contains(input.midi) {
                held.remove(input.midi)
            }
        }
        monitor?(input)
        events.send(input)
    }

    func press(_ midi: Int, source: NoteInput.Source) {
        send(NoteInput(kind: .on, midi: midi, velocity: 90, time: HostClock.now, source: source))
    }

    func release(_ midi: Int, source: NoteInput.Source) {
        send(NoteInput(kind: .off, midi: midi, velocity: 0, time: HostClock.now, source: source))
    }

    /// Lets the computer keyboard stand in for a piano when no MIDI keyboard is plugged in.
    /// On iPhone and iPad the on-screen keys are played by touch instead.
    func installComputerKeyboard() {
        #if os(macOS)
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKey(event) ? nil : event
        }
        #endif
    }

    #if os(macOS)
    private func handleKey(_ event: NSEvent) -> Bool {
        let blocked: NSEvent.ModifierFlags = [.command, .control, .option]
        if !event.modifierFlags.intersection(blocked).isEmpty { return false }
        let code: UInt16 = event.keyCode

        if event.type == .keyDown && (code == ComputerKeyboard.octaveDown || code == ComputerKeyboard.octaveUp) {
            if !event.isARepeat {
                let change: Int = code == ComputerKeyboard.octaveDown ? -1 : 1
                octaveShift = min(max(octaveShift + change, -2), 2)
            }
            return true
        }

        if event.type == .keyUp {
            if let midi = activeKeys.removeValue(forKey: event.keyCode) {
                release(midi, source: .computerKeys)
                return true
            }
            return false
        }

        guard let base = InputHub.keyMap[code] else { return false }
        if event.isARepeat { return true }
        let midi: Int = base + 12 * octaveShift
        activeKeys[event.keyCode] = midi
        press(midi, source: .computerKeys)
        return true
    }
    #endif
}

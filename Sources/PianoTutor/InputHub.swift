import Foundation
import AppKit
import Combine

struct NoteInput {
    enum Kind {
        case on
        case off
    }

    enum Source {
        case midi
        case computerKeys
        case mouse
    }

    let kind: Kind
    let midi: Int
    let velocity: Int
    let time: TimeInterval
    let source: Source
}

/// Merges notes from the MIDI keyboard, the on-screen keys and the computer keyboard into one stream.
final class InputHub: ObservableObject {
    @Published private(set) var held: Set<Int> = []
    @Published private(set) var octaveShift: Int = 0

    let events = PassthroughSubject<NoteInput, Never>()

    /// Called for every note before listeners, used to play the sound.
    var monitor: ((NoteInput) -> Void)?

    private var keyMonitor: Any?
    private var activeKeys: [UInt16: Int] = [:]

    /// Home-row keys play the white keys from Middle C; the row above plays the black keys.
    private static let keyMap: [String: Int] = [
        "a": 60, "w": 61, "s": 62, "e": 63, "d": 64, "f": 65, "t": 66,
        "g": 67, "y": 68, "h": 69, "u": 70, "j": 71, "k": 72, "o": 73,
        "l": 74, "p": 75, ";": 76,
    ]

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
    func installComputerKeyboard() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let blocked: NSEvent.ModifierFlags = [.command, .control, .option]
        if !event.modifierFlags.intersection(blocked).isEmpty { return false }
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }

        if event.type == .keyDown && (characters == "z" || characters == "x") {
            if !event.isARepeat {
                let change: Int = characters == "z" ? -1 : 1
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

        guard let base = InputHub.keyMap[characters] else { return false }
        if event.isARepeat { return true }
        let midi: Int = base + 12 * octaveShift
        activeKeys[event.keyCode] = midi
        press(midi, source: .computerKeys)
        return true
    }
}

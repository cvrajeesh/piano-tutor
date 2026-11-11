import Foundation
import CoreMIDI

struct MIDINoteMessage {
    let isOn: Bool
    let note: Int
    let velocity: Int
    let time: TimeInterval
}

/// Listens to every MIDI source on the system (for example "CASIO USB-MIDI")
/// and reports note-on and note-off messages on the main thread.
final class MIDIManager: ObservableObject {
    @Published private(set) var sourceNames: [String] = []

    /// Called on the main thread.
    var onNote: ((MIDINoteMessage) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var started: Bool = false

    /// Number of 32-bit words in a Universal MIDI Packet, by message type.
    private static let wordsPerMessage: [Int] = [1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4]

    var isConnected: Bool {
        return !sourceNames.isEmpty
    }

    func start() {
        guard !started else { return }
        started = true

        let clientStatus = MIDIClientCreateWithBlock("Middle C" as CFString, &client) { [weak self] notification in
            let id = notification.pointee.messageID
            if id == .msgSetupChanged || id == .msgObjectAdded || id == .msgObjectRemoved {
                DispatchQueue.main.async {
                    self?.refreshSources()
                }
            }
        }
        guard clientStatus == noErr else { return }

        let portStatus = MIDIInputPortCreateWithProtocol(client, "Input" as CFString, ._1_0, &inputPort) { [weak self] eventList, _ in
            self?.receive(eventList)
        }
        guard portStatus == noErr else { return }

        refreshSources()
    }

    func refreshSources() {
        var names: [String] = []
        let count: Int = MIDIGetNumberOfSources()
        for index in 0..<count {
            let source: MIDIEndpointRef = MIDIGetSource(index)
            if source == 0 { continue }
            // Connecting a source that is already connected is harmless.
            MIDIPortConnectSource(inputPort, source, nil)
            names.append(MIDIManager.displayName(of: source))
        }
        if names != sourceNames {
            sourceNames = names
        }
    }

    private static func displayName(of object: MIDIObjectRef) -> String {
        var value: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(object, kMIDIPropertyDisplayName, &value)
        if status == noErr, let name = value?.takeRetainedValue() {
            return name as String
        }
        return String(localized: "MIDI keyboard", comment: "Name shown for a connected keyboard that does not report its own name")
    }

    private func receive(_ eventList: UnsafePointer<MIDIEventList>) {
        var messages: [MIDINoteMessage] = []
        let wordsOffset: Int = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words) ?? 12

        for packet in eventList.unsafeSequence() {
            let wordCount: Int = Int(packet.pointee.wordCount)
            let stamp: UInt64 = packet.pointee.timeStamp
            let time: TimeInterval = stamp == 0 ? HostClock.now : HostClock.seconds(fromHostTime: stamp)
            let words = UnsafeRawPointer(packet).advanced(by: wordsOffset).assumingMemoryBound(to: UInt32.self)

            var index: Int = 0
            while index < wordCount {
                let word: UInt32 = words[index]
                let messageType: Int = Int((word >> 28) & 0xF)
                if messageType == 0x2 {
                    // MIDI 1.0 channel voice message: status, data 1, data 2.
                    let status: UInt32 = (word >> 16) & 0xF0
                    let note: Int = Int((word >> 8) & 0x7F)
                    let velocity: Int = Int(word & 0x7F)
                    if status == 0x90 && velocity > 0 {
                        messages.append(MIDINoteMessage(isOn: true, note: note, velocity: velocity, time: time))
                    } else if status == 0x80 || status == 0x90 {
                        messages.append(MIDINoteMessage(isOn: false, note: note, velocity: 0, time: time))
                    }
                }
                index += MIDIManager.wordsPerMessage[messageType]
            }
        }

        if messages.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for message in messages {
                self.onNote?(message)
            }
        }
    }
}

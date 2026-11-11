// swift-tools-version: 5.9
import PackageDescription

// PianoTutorCore is pure Swift (notation, scoring, lesson content) and builds anywhere.
// The app itself needs SwiftUI, CoreMIDI and AVFoundation, so it is macOS-only.
var products: [Product] = [
    .library(name: "PianoTutorCore", targets: ["PianoTutorCore"])
]
var targets: [Target] = [
    .target(name: "PianoTutorCore"),
    .testTarget(name: "PianoTutorCoreTests", dependencies: ["PianoTutorCore"]),
]

#if os(macOS)
products.append(.executable(name: "PianoTutor", targets: ["PianoTutor"]))
targets.append(
    .executableTarget(
        name: "PianoTutor",
        dependencies: ["PianoTutorCore"],
        exclude: ["Resources"]
    )
)
#endif

let package = Package(
    name: "PianoTutor",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)

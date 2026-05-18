// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NotesCore",
    defaultLocalization: "ja",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "NotesCore", targets: ["NotesCore"])
    ],
    targets: [
        .target(
            name: "NotesCore",
            path: "Sources/NotesCore"
        ),
        .testTarget(
            name: "NotesCoreTests",
            dependencies: ["NotesCore"],
            path: "Tests/NotesCoreTests"
        )
    ]
)

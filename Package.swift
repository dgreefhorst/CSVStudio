// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CSVStudio",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CSVStudio",
            path: "Sources/CSVStudio"
        )
    ]
)

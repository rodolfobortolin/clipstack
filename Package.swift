// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Clipstack",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Clipstack",
            path: "Sources/Clipstack",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)

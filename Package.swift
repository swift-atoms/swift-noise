// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-noise",
    platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27), .visionOS(.v27)],
    products: [.library(name: "Noise", targets: ["Noise"])],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-point.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-threefry.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-vector.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Noise",
            dependencies: [
                .product(name: "Point", package: "swift-point"),
                .product(name: "Threefry", package: "swift-threefry"),
                .product(name: "Vector", package: "swift-vector"),
            ]
        ),
        .testTarget(
            name: "Noise Tests",
            dependencies: [
                .target(name: "Noise")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}

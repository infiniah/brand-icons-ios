// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrandIcons",
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10), .tvOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "BrandIcons", targets: ["BrandIcons"])
    ],
    targets: [
        .target(
            name: "BrandIcons",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BrandIconsTests",
            dependencies: ["BrandIcons"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Perch",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/httpswift/swifter.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Perch",
            dependencies: [
                .product(name: "Swifter", package: "swifter")
            ],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

// swift-tools-version: 6.2

import Foundation
import PackageDescription

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let cubismLibraryPath = "\(packageRoot)/.build/cubism/lib"

let package = Package(
    name: "BongoCat",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "BongoCat", targets: ["BongoCat"]),
    ],
    targets: [
        .target(
            name: "CubismAPI",
            path: "Sources/CubismAPI",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags([
                    "-L\(cubismLibraryPath)",
                    "-lBongoCubism",
                    "-lFramework",
                    "-lLive2DCubismCore",
                    "-lc++",
                ]),
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation"),
                .linkedFramework("GameController"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
            ]
        ),
        .executableTarget(
            name: "BongoCat",
            dependencies: ["CubismAPI"],
            path: "Sources/BongoCat"
        ),
        .testTarget(
            name: "BongoCatTests",
            dependencies: ["BongoCat", "CubismAPI"],
            path: "Tests/BongoCatTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

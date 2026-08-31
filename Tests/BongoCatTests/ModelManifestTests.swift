import AppKit
import CubismAPI
import Foundation
import Testing
@testable import BongoCat

@Suite("Live2D behavior discovery")
@MainActor
struct ModelManifestTests {
    @Test("Every bundled model exposes valid motions, expressions, and optional sound")
    func bundledBehaviors() throws {
        for mode in CatModelMode.allCases {
            let manifest = try ModelManifest.load(
                from: modelsRoot.appendingPathComponent(mode.rawValue, isDirectory: true)
            )
            #expect(manifest.motions.count == 4)
            #expect(manifest.expressions.count == 3)
            #expect(manifest.motions.allSatisfy {
                FileManager.default.fileExists(atPath: $0.fileURL.path)
            })
            #expect(manifest.expressions.allSatisfy {
                FileManager.default.fileExists(atPath: $0.fileURL.path)
            })
        }

        let gamepad = try ModelManifest.load(
            from: modelsRoot.appendingPathComponent("gamepad", isDirectory: true)
        )
        #expect(gamepad.detectedMode == .gamepad)
        #expect(gamepad.motions.contains { $0.soundURL != nil })
    }

    @Test("Cubism accepts a discovered motion and expression")
    func cubismAcceptsBehaviors() throws {
        let directory = modelsRoot.appendingPathComponent("standard", isDirectory: true)
        let manifest = try ModelManifest.load(from: directory)
        try BCCubismView.validateModelDirectory(
            directory,
            motionFileURL: #require(manifest.motions.first).fileURL,
            expressionFileURL: #require(manifest.expressions.first).fileURL
        )
    }

    @Test("Cubism loads optional physics and pose for imported models")
    func cubismAcceptsPhysicsAndPose() throws {
        let sdkRoot = try #require(
            ProcessInfo.processInfo.environment["CUBISM_SDK_ROOT"],
            "Set CUBISM_SDK_ROOT to the extracted Cubism SDK for Native folder."
        )
        let directory = URL(fileURLWithPath: sdkRoot)
            .appendingPathComponent("Samples/Resources/Mao", isDirectory: true)
        let manifest = try ModelManifest.load(from: directory)

        #expect(manifest.physicsURL != nil)
        #expect(manifest.poseURL != nil)
        try BCCubismView.validateModelDirectory(directory)
    }

    private var modelsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Models", isDirectory: true)
    }
}

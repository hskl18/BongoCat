import AppKit
import CubismAPI
import Foundation
import Testing
@testable import BongoCat

@Suite("Cat input reactions")
@MainActor
struct CatSceneTests {
    @Test("A keyboard press shows and releases its paw overlay")
    func keyboardPressAndRelease() {
        let scene = makeScene()

        scene.handleKey(code: 0, isDown: true)
        #expect(scene.leftHandImage != nil)

        scene.handleKey(code: 0, isDown: false)
        #expect(scene.leftHandImage == nil)
    }

    @Test("Releasing the newest key restores an older key still held by the same paw")
    func overlappingKeysRestorePreviousOverlay() {
        let scene = makeScene()

        scene.handleKey(code: 0, isDown: true)
        scene.handleKey(code: 1, isDown: true)
        scene.handleKey(code: 1, isDown: false)
        #expect(scene.leftHandImage != nil)

        scene.handleKey(code: 0, isDown: false)
        #expect(scene.leftHandImage == nil)
    }

    @Test("Function keys and either Command key use the model fallback assets")
    func functionAndCommandFallbacks() {
        let scene = makeScene()

        scene.handleKey(code: 122, isDown: true)
        #expect(scene.leftHandImage != nil)
        scene.handleKey(code: 122, isDown: false)

        scene.handleKey(code: 54, isDown: true)
        #expect(scene.leftHandImage != nil)
        scene.handleKey(code: 54, isDown: false)
        #expect(scene.leftHandImage == nil)
    }

    @Test("Caps Lock releases its overlay without waiting for the next toggle")
    func capsLockAutoRelease() async throws {
        let scene = makeScene()

        scene.handleKey(code: 57, isDown: true)
        #expect(scene.leftHandImage != nil)
        try await Task.sleep(for: .milliseconds(150))

        #expect(scene.leftHandImage == nil)
    }

    @Test("Pointer damping matches the upstream quarter-step at 60 FPS")
    func pointerDamping() {
        let current = CGPoint(x: 0, y: 0)
        let target = CGPoint(x: 1, y: 1)

        let next = PointerSmoother.step(current: current, target: target, elapsed: 1.0 / 60.0)

        #expect(abs(next.x - 0.25) < 0.000_001)
        #expect(abs(next.y - 0.25) < 0.000_001)
        #expect(!PointerSmoother.isSettled(current: next, target: target))
    }

    @Test("Changing the model selects its real Cubism directory immediately")
    func modelChangeUsesNewPreset() {
        let settings = AppSettings(defaults: makeDefaults())
        let scene = CatSceneState(
            settings: settings,
            resources: ModelResourceCatalog(rootURL: modelsRoot)
        )

        settings.modelMode = .keyboard

        #expect(scene.modelDirectory == modelsRoot.appendingPathComponent("keyboard", isDirectory: true))
    }

    @Test("Left and right mouse buttons keep independent state")
    func overlappingMouseButtons() {
        let scene = makeScene()

        scene.handleMouse(button: .left, isDown: true)
        scene.handleMouse(button: .right, isDown: true)
        scene.handleMouse(button: .left, isDown: false)
        #expect(scene.leftMouseDown == false)
        #expect(scene.rightMouseDown == true)

        scene.handleMouse(button: .right, isDown: false)
        #expect(scene.leftMouseDown == false)
        #expect(scene.rightMouseDown == false)
    }

    @Test("Gamepad sticks and buttons drive the original model parameters and overlays")
    func gamepadInput() {
        let defaults = makeDefaults()
        defaults.set(CatModelMode.gamepad.rawValue, forKey: "native.model.mode")
        let scene = CatSceneState(
            settings: AppSettings(defaults: defaults),
            resources: ModelResourceCatalog(rootURL: modelsRoot)
        )

        scene.handleGamepad(input: .leftStickX, value: 0.75)
        #expect(scene.gamepadParameters["CatParamStickLX"] == 0.75)
        #expect(scene.gamepadParameters["CatParamStickShowLeftHand"] == 1)
        #expect(scene.leftHandActive == true)

        scene.handleGamepad(input: .south, value: 1)
        #expect(scene.rightHandImage != nil)
        scene.handleGamepad(input: .south, value: 0)
        #expect(scene.rightHandImage == nil)

        scene.resetGamepad()
        #expect(scene.gamepadParameters.isEmpty)
        #expect(scene.leftHandActive == false)
    }

    @Test("Pointer reset returns every model to its neutral center")
    func pointerReset() {
        let scene = makeScene()

        scene.updatePointer(NSPoint(x: -10_000, y: -10_000))
        scene.resetPointer()

        #expect(scene.pointerRatio == CGPoint(x: 0.5, y: 0.5))
    }

    @Test("Cubism Core accepts every bundled moc3 model")
    func loadsRealCubismModels() throws {
        for mode in CatModelMode.allCases {
            let directory = modelsRoot.appendingPathComponent(mode.rawValue, isDirectory: true)
            #expect(FileManager.default.fileExists(atPath: directory.path))
            try BCCubismView.validateModelDirectory(directory)
        }
    }

    @Test("Real Cubism drawables react to keyboard, mouse, and pointer parameters")
    func realModelParametersChangeDrawables() throws {
        let directory = modelsRoot.appendingPathComponent(CatModelMode.standard.rawValue, isDirectory: true)
        for parameterID in [
            "CatParamLeftHandDown",
            "ParamMouseLeftDown",
            "ParamMouseRightDown",
            "ParamMouseX",
            "ParamMouseY",
        ] {
            try BCCubismView.validateModelDirectory(
                directory,
                parameterChangesModel: parameterID,
                fromValue: 0,
                toValue: 1
            )
        }
    }

    private func makeScene() -> CatSceneState {
        CatSceneState(
            settings: AppSettings(defaults: makeDefaults()),
            resources: ModelResourceCatalog(rootURL: modelsRoot)
        )
    }

    private var modelsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Models", isDirectory: true)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

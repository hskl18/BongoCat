import AppKit
import AVFoundation
import Combine
import CubismAPI
import SwiftUI

enum CatHand {
    case left
    case right
}

enum CatMouseButton: Hashable, Sendable {
    case left
    case right
}

enum GamepadInput: String, CaseIterable, Sendable {
    case south = "South"
    case east = "East"
    case west = "West"
    case north = "North"
    case leftShoulder = "LeftTrigger"
    case leftTrigger = "LeftTrigger2"
    case rightShoulder = "RightTrigger"
    case rightTrigger = "RightTrigger2"
    case dPadUp = "DPadUp"
    case dPadDown = "DPadDown"
    case dPadLeft = "DPadLeft"
    case dPadRight = "DPadRight"
    case leftStickX = "LeftStickX"
    case leftStickY = "LeftStickY"
    case rightStickX = "RightStickX"
    case rightStickY = "RightStickY"
    case leftThumb = "LeftThumb"
    case rightThumb = "RightThumb"
}

struct MotionPlaybackRequest: Equatable, Sendable {
    let id = UUID()
    let motion: ModelMotion
}

struct ExpressionPlaybackRequest: Equatable, Sendable {
    let id = UUID()
    let expression: ModelExpression
}

struct ModelResourceCatalog {
    let rootURL: URL?

    init(bundle: Bundle = .main) {
        rootURL = bundle.resourceURL?.appendingPathComponent("Models", isDirectory: true)
    }

    init(rootURL: URL?) {
        self.rootURL = rootURL
    }

    func image(named name: String, mode: CatModelMode) -> NSImage? {
        guard let directory = modelDirectory(mode: mode) else { return nil }
        return image(named: name, directory: directory)
    }

    func image(named name: String, directory: URL) -> NSImage? {
        let url = directory
            .appendingPathComponent("resources", isDirectory: true)
            .appendingPathComponent(name)
            .appendingPathExtension("png")
        return NSImage(contentsOf: url)
    }

    func keyImage(named name: String, mode: CatModelMode) -> (hand: CatHand, image: NSImage)? {
        guard let directory = modelDirectory(mode: mode) else { return nil }
        return keyImage(named: name, directory: directory)
    }

    func keyImage(named name: String, directory modelDirectory: URL) -> (hand: CatHand, image: NSImage)? {
        for (keyDirectory, hand) in [("left-keys", CatHand.left), ("right-keys", CatHand.right)] {
            let url = modelDirectory
                .appendingPathComponent("resources", isDirectory: true)
                .appendingPathComponent(keyDirectory, isDirectory: true)
                .appendingPathComponent(name)
                .appendingPathExtension("png")

            if let image = NSImage(contentsOf: url) {
                return (hand, image)
            }
        }
        return nil
    }

    func modelDirectory(mode: CatModelMode) -> URL? {
        guard let directory = rootURL?.appendingPathComponent(mode.rawValue, isDirectory: true),
              FileManager.default.fileExists(
                  atPath: directory.appendingPathComponent("cat.model3.json").path
              )
        else { return nil }
        return directory
    }

}

@MainActor
final class CatSceneState: ObservableObject {
    private struct PressedKey {
        let hand: CatHand
        let image: NSImage
        let sequence: Int
    }

    private let settings: AppSettings
    private let resources: ModelResourceCatalog
    private let modelLibrary: ModelLibrary?
    private var activeModelMode: CatModelMode
    private var activeModelDirectory: URL?
    private var pressedKeys: [String: PressedKey] = [:]
    private var pressedMouseButtons: Set<CatMouseButton> = []
    private var gamepadValues: [GamepadInput: Double] = [:]
    private var sequence = 0
    private var autoReleaseTasks: [UInt16: DispatchWorkItem] = [:]
    private var pointerTarget = CGPoint(x: 0.5, y: 0.5)
    private var pointerSmoothingTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var backgroundImage: NSImage?
    @Published private(set) var modelDirectory: URL?
    @Published private(set) var leftHandImage: NSImage?
    @Published private(set) var rightHandImage: NSImage?
    @Published private(set) var leftMouseDown = false
    @Published private(set) var rightMouseDown = false
    @Published private(set) var pointerRatio = CGPoint(x: 0.5, y: 0.5)
    @Published private(set) var leftHandActive = false
    @Published private(set) var rightHandActive = false
    @Published private(set) var gamepadParameters: [String: Double] = [:]
    @Published private(set) var motions: [ModelMotion] = []
    @Published private(set) var expressions: [ModelExpression] = []
    @Published private(set) var motionRequest: MotionPlaybackRequest?
    @Published private(set) var expressionRequest: ExpressionPlaybackRequest?

    init(
        settings: AppSettings,
        resources: ModelResourceCatalog = ModelResourceCatalog(),
        modelLibrary: ModelLibrary? = nil
    ) {
        self.settings = settings
        self.resources = resources
        self.modelLibrary = modelLibrary
        activeModelMode = settings.modelMode

        if let modelLibrary {
            reloadModel(record: modelLibrary.selectedModel)
            modelLibrary.$selectedID
                .combineLatest(modelLibrary.$models)
                .sink { [weak self, weak modelLibrary] _, _ in
                    self?.reloadModel(record: modelLibrary?.selectedModel)
                }
                .store(in: &cancellables)
        } else {
            reloadModel()
            settings.$modelMode
                .removeDuplicates()
                .sink { [weak self] mode in self?.reloadModel(mode: mode) }
                .store(in: &cancellables)
        }
    }

    func handleKey(code: UInt16, isDown: Bool) {
        guard let assetName = KeyAssetName.assetName(for: code) else { return }
        updateOverlay(
            identifier: "keyboard.\(code)",
            assetName: assetName,
            isDown: isDown
        )
        guard code == 57 else { return }
        autoReleaseTasks[code]?.cancel()
        guard isDown else {
            autoReleaseTasks.removeValue(forKey: code)
            return
        }
        let release = DispatchWorkItem { [weak self] in
            self?.updateOverlay(
                identifier: "keyboard.\(code)",
                assetName: assetName,
                isDown: false
            )
            self?.autoReleaseTasks.removeValue(forKey: code)
        }
        autoReleaseTasks[code] = release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: release)
    }

    func handleGamepad(input: GamepadInput, value: Double) {
        guard activeModelMode == .gamepad else { return }
        let normalized = value.clamped(to: -1 ... 1)
        gamepadValues[input] = normalized

        switch input {
        case .leftStickX:
            gamepadParameters["CatParamStickLX"] = normalized
        case .leftStickY:
            gamepadParameters["CatParamStickLY"] = normalized
        case .rightStickX:
            gamepadParameters["CatParamStickRX"] = normalized
        case .rightStickY:
            gamepadParameters["CatParamStickRY"] = normalized
        case .leftThumb:
            gamepadParameters["CatParamStickLeftDown"] = normalized > 0 ? 1 : 0
        case .rightThumb:
            gamepadParameters["CatParamStickRightDown"] = normalized > 0 ? 1 : 0
        default:
            updateOverlay(
                identifier: "gamepad.\(input.rawValue)",
                assetName: input.rawValue,
                isDown: normalized > 0
            )
        }
        refreshGamepadHands()
    }

    func resetGamepad() {
        gamepadValues.removeAll()
        gamepadParameters.removeAll()
        pressedKeys = pressedKeys.filter { !$0.key.hasPrefix("gamepad.") }
        refreshHandImages()
    }

    func handleMouse(button: CatMouseButton, isDown: Bool) {
        if isDown {
            pressedMouseButtons.insert(button)
        } else {
            pressedMouseButtons.remove(button)
        }
        leftMouseDown = pressedMouseButtons.contains(.left)
        rightMouseDown = pressedMouseButtons.contains(.right)
    }

    func updatePointer(_ point: NSPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else {
            resetPointer()
            return
        }

        let target = CGPoint(
            x: ((point.x - screen.frame.minX) / max(screen.frame.width, 1)).clamped(to: 0 ... 1),
            y: ((screen.frame.maxY - point.y) / max(screen.frame.height, 1)).clamped(to: 0 ... 1)
        )
        pointerTarget = target
        startPointerSmoothingIfNeeded()
    }

    func resetPointer() {
        pointerSmoothingTask?.cancel()
        pointerSmoothingTask = nil
        pointerTarget = CGPoint(x: 0.5, y: 0.5)
        guard pointerRatio != pointerTarget else { return }
        pointerRatio = CGPoint(x: 0.5, y: 0.5)
    }

    func play(_ motion: ModelMotion) {
        guard settings.behaviorsEnabled else { return }
        motionRequest = MotionPlaybackRequest(motion: motion)
    }

    func apply(_ expression: ModelExpression) {
        guard settings.behaviorsEnabled else { return }
        expressionRequest = ExpressionPlaybackRequest(expression: expression)
    }

    private func reloadModel(mode: CatModelMode? = nil) {
        let selectedMode = mode ?? settings.modelMode
        loadModel(
            directory: resources.modelDirectory(mode: selectedMode),
            mode: selectedMode
        )
    }

    private func reloadModel(record: ModelRecord?) {
        loadModel(directory: record?.directoryURL, mode: record?.mode ?? .standard)
    }

    private func loadModel(directory: URL?, mode: CatModelMode) {
        pressedKeys.removeAll()
        for task in autoReleaseTasks.values { task.cancel() }
        autoReleaseTasks.removeAll()
        pointerSmoothingTask?.cancel()
        pointerSmoothingTask = nil
        pressedMouseButtons.removeAll()
        gamepadValues.removeAll()
        gamepadParameters.removeAll()
        activeModelMode = mode
        activeModelDirectory = directory
        backgroundImage = directory.flatMap { resources.image(named: "background", directory: $0) }
        modelDirectory = directory
        if let modelDirectory, let manifest = try? ModelManifest.load(from: modelDirectory) {
            motions = manifest.motions
            expressions = manifest.expressions
        } else {
            motions = []
            expressions = []
        }
        motionRequest = nil
        expressionRequest = nil
        leftHandImage = nil
        rightHandImage = nil
        leftMouseDown = false
        rightMouseDown = false
        leftHandActive = false
        rightHandActive = false
    }

    private func startPointerSmoothingIfNeeded() {
        guard pointerRatio != pointerTarget, pointerSmoothingTask == nil else { return }
        pointerSmoothingTask = Task { @MainActor [weak self] in
            let clock = ContinuousClock()
            var lastFrame = clock.now
            while !Task.isCancelled, let self {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { break }
                let now = clock.now
                let duration = lastFrame.duration(to: now).components
                lastFrame = now
                let elapsed = Double(duration.seconds)
                    + Double(duration.attoseconds) / 1_000_000_000_000_000_000
                self.pointerRatio = PointerSmoother.step(
                    current: self.pointerRatio,
                    target: self.pointerTarget,
                    elapsed: elapsed
                )
                if PointerSmoother.isSettled(current: self.pointerRatio, target: self.pointerTarget) {
                    self.pointerRatio = self.pointerTarget
                    break
                }
            }
            self?.pointerSmoothingTask = nil
        }
    }

    private func refreshHandImages() {
        leftHandImage = mostRecentImage(for: .left)
        rightHandImage = mostRecentImage(for: .right)
        refreshHandActivity()
    }

    private func updateOverlay(identifier: String, assetName: String, isDown: Bool) {
        if isDown {
            guard pressedKeys[identifier] == nil,
                  let activeModelDirectory,
                  let resource = resources.keyImage(named: assetName, directory: activeModelDirectory)
            else { return }
            sequence += 1
            pressedKeys[identifier] = PressedKey(
                hand: resource.hand,
                image: resource.image,
                sequence: sequence
            )
        } else {
            pressedKeys.removeValue(forKey: identifier)
        }
        refreshHandImages()
    }

    private func refreshGamepadHands() {
        let leftActive = stickIsActive(x: .leftStickX, y: .leftStickY, thumb: .leftThumb)
        let rightActive = stickIsActive(x: .rightStickX, y: .rightStickY, thumb: .rightThumb)
        gamepadParameters["CatParamStickShowLeftHand"] = leftActive ? 1 : 0
        gamepadParameters["CatParamStickShowRightHand"] = rightActive ? 1 : 0
        refreshHandActivity()
    }

    private func refreshHandActivity() {
        leftHandActive = leftHandImage != nil
            || stickIsActive(x: .leftStickX, y: .leftStickY, thumb: .leftThumb)
        rightHandActive = rightHandImage != nil
            || stickIsActive(x: .rightStickX, y: .rightStickY, thumb: .rightThumb)
    }

    private func stickIsActive(x: GamepadInput, y: GamepadInput, thumb: GamepadInput) -> Bool {
        abs(gamepadValues[x, default: 0]) > 0.001
            || abs(gamepadValues[y, default: 0]) > 0.001
            || gamepadValues[thumb, default: 0] > 0
    }

    private func mostRecentImage(for hand: CatHand) -> NSImage? {
        pressedKeys.values
            .filter { $0.hand == hand }
            .max { $0.sequence < $1.sequence }?
            .image
    }
}

private enum KeyAssetName {
    private static let names: [UInt16: String] = [
        0: "KeyA", 1: "KeyS", 2: "KeyD", 3: "KeyF", 4: "KeyH", 5: "KeyG",
        6: "KeyZ", 7: "KeyX", 8: "KeyC", 9: "KeyV", 11: "KeyB", 12: "KeyQ",
        13: "KeyW", 14: "KeyE", 15: "KeyR", 16: "KeyY", 17: "KeyT", 18: "Num1",
        19: "Num2", 20: "Num3", 21: "Num4", 22: "Num6", 23: "Num5", 25: "Num9",
        26: "Num7", 28: "Num8", 29: "Num0", 31: "KeyO", 32: "KeyU", 34: "KeyI",
        35: "KeyP", 36: "Return", 37: "KeyL", 38: "KeyJ", 40: "KeyK", 44: "Slash",
        45: "KeyN", 46: "KeyM", 48: "Tab", 49: "Space", 50: "BackQuote",
        51: "Backspace", 53: "Escape", 54: "Meta", 55: "Meta", 56: "ShiftLeft", 57: "CapsLock",
        58: "Alt", 59: "ControlLeft", 60: "ShiftRight", 61: "AltGr", 62: "ControlRight",
        63: "Fn", 117: "Delete", 123: "LeftArrow", 124: "RightArrow",
        125: "DownArrow", 126: "UpArrow",
        96: "Fn", 97: "Fn", 98: "Fn", 99: "Fn", 100: "Fn", 101: "Fn",
        103: "Fn", 109: "Fn", 111: "Fn", 118: "Fn", 120: "Fn", 122: "Fn",
    ]

    static func assetName(for keyCode: UInt16) -> String? {
        names[keyCode]
    }
}

enum PointerSmoother {
    static func step(current: CGPoint, target: CGPoint, elapsed: TimeInterval) -> CGPoint {
        let frameDuration = 1.0 / 60.0
        let alpha = 1 - pow(0.75, max(elapsed, 0) / frameDuration)
        return CGPoint(
            x: current.x + (target.x - current.x) * alpha,
            y: current.y + (target.y - current.y) * alpha
        )
    }

    static func isSettled(current: CGPoint, target: CGPoint) -> Bool {
        hypot(target.x - current.x, target.y - current.y) < 0.00025
    }
}

struct CatCanvasView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scene: CatSceneState

    var body: some View {
        ZStack {
            if let backgroundImage = scene.backgroundImage {
                modelImage(backgroundImage)
            }

            if let modelDirectory = scene.modelDirectory {
                CubismMetalView(
                    modelDirectory: modelDirectory,
                    pointerRatio: scene.pointerRatio,
                    pointerMirrored: settings.mouseMirror,
                    leftMouseDown: scene.leftMouseDown,
                    rightMouseDown: scene.rightMouseDown,
                    leftHandDown: scene.leftHandActive,
                    rightHandDown: scene.rightHandActive,
                    parameterValues: scene.gamepadParameters,
                    motionRequest: scene.motionRequest,
                    expressionRequest: scene.expressionRequest,
                    motionSoundEnabled: settings.motionSound,
                    maximumFramesPerSecond: settings.maximumFramesPerSecond
                )
            } else {
                ContentUnavailableView(
                    L10n.text(
                        "model.unavailable",
                        language: settings.language,
                        fallback: "Model resources unavailable"
                    ),
                    systemImage: "cat.fill"
                )
            }

            if let leftHandImage = scene.leftHandImage {
                modelImage(leftHandImage)
            }

            if let rightHandImage = scene.rightHandImage {
                modelImage(rightHandImage)
            }
        }
        .clipShape(PercentageRoundedRectangle(percent: settings.cornerRadius))
        .scaleEffect(x: settings.mirror ? -1 : 1, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bongo Cat")
    }

    private func modelImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

}

private struct CubismMetalView: NSViewRepresentable {
    let modelDirectory: URL
    let pointerRatio: CGPoint
    let pointerMirrored: Bool
    let leftMouseDown: Bool
    let rightMouseDown: Bool
    let leftHandDown: Bool
    let rightHandDown: Bool
    let parameterValues: [String: Double]
    let motionRequest: MotionPlaybackRequest?
    let expressionRequest: ExpressionPlaybackRequest?
    let motionSoundEnabled: Bool
    let maximumFramesPerSecond: Int

    func makeNSView(context: Context) -> CubismHostView {
        CubismHostView(modelDirectory: modelDirectory)
    }

    func updateNSView(_ host: CubismHostView, context: Context) {
        host.update(
            modelDirectory: modelDirectory,
            pointerRatio: pointerRatio,
            pointerMirrored: pointerMirrored,
            leftMouseDown: leftMouseDown,
            rightMouseDown: rightMouseDown,
            leftHandDown: leftHandDown,
            rightHandDown: rightHandDown,
            parameterValues: parameterValues,
            motionRequest: motionRequest,
            expressionRequest: expressionRequest,
            motionSoundEnabled: motionSoundEnabled,
            maximumFramesPerSecond: maximumFramesPerSecond
        )
    }
}

private final class CubismHostView: NSView {
    private var cubismView: BCCubismView?
    private var modelDirectory: URL?
    private var lastMotionRequestID: UUID?
    private var lastExpressionRequestID: UUID?
    private var audioPlayer: AVAudioPlayer?

    init(modelDirectory: URL) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        load(modelDirectory)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func update(
        modelDirectory: URL,
        pointerRatio: CGPoint,
        pointerMirrored: Bool,
        leftMouseDown: Bool,
        rightMouseDown: Bool,
        leftHandDown: Bool,
        rightHandDown: Bool,
        parameterValues: [String: Double],
        motionRequest: MotionPlaybackRequest?,
        expressionRequest: ExpressionPlaybackRequest?,
        motionSoundEnabled: Bool,
        maximumFramesPerSecond: Int
    ) {
        if self.modelDirectory != modelDirectory {
            load(modelDirectory)
        }
        cubismView?.setPointerXRatio(
            pointerRatio.x,
            yRatio: pointerRatio.y,
            mirrored: pointerMirrored
        )
        cubismView?.setLeftMouseDown(
            leftMouseDown,
            rightMouseDown: rightMouseDown,
            leftHandDown: leftHandDown,
            rightHandDown: rightHandDown
        )
        cubismView?.setParameterValues(
            parameterValues.mapValues { NSNumber(value: $0) }
        )
        let frameRate = maximumFramesPerSecond == 0
            ? max(NSScreen.main?.maximumFramesPerSecond ?? 60, 60)
            : maximumFramesPerSecond
        cubismView?.setMaximumFramesPerSecond(frameRate)
        if let motionRequest, motionRequest.id != lastMotionRequestID {
            do {
                try cubismView?.startMotionFileURL(motionRequest.motion.fileURL)
                playSound(motionRequest.motion.soundURL, enabled: motionSoundEnabled)
                lastMotionRequestID = motionRequest.id
            } catch {
                NSLog("BongoCat motion failed: %@", error.localizedDescription)
            }
        }
        if let expressionRequest, expressionRequest.id != lastExpressionRequestID {
            do {
                try cubismView?.setExpressionFileURL(expressionRequest.expression.fileURL)
                lastExpressionRequestID = expressionRequest.id
            } catch {
                NSLog("BongoCat expression failed: %@", error.localizedDescription)
            }
        }
        if !motionSoundEnabled {
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }

    private func load(_ directory: URL) {
        if let cubismView {
            do {
                try cubismView.loadModelDirectory(directory)
            } catch {
                NSLog("BongoCat Cubism load failed: %@", error.localizedDescription)
                return
            }
            modelDirectory = directory
            audioPlayer?.stop()
            audioPlayer = nil
            return
        }

        let view: BCCubismView
        do {
            view = try BCCubismView(frame: bounds, modelDirectory: directory)
        } catch {
            NSLog("BongoCat Cubism load failed: %@", error.localizedDescription)
            return
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        cubismView = view
        modelDirectory = directory
    }

    private func playSound(_ soundURL: URL?, enabled: Bool) {
        audioPlayer?.stop()
        audioPlayer = nil
        guard enabled, let soundURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            NSLog("BongoCat motion sound failed: %@", error.localizedDescription)
        }
    }
}

private struct PercentageRoundedRectangle: Shape {
    let percent: Double

    func path(in rect: CGRect) -> Path {
        let normalized = min(max(percent, 0), 50) / 100
        let radius = min(rect.width, rect.height) * normalized
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

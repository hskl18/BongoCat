import AppKit
import Combine
import Foundation

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let shift = ShortcutModifiers(rawValue: 1 << 1)
    static let option = ShortcutModifiers(rawValue: 1 << 2)
    static let control = ShortcutModifiers(rawValue: 1 << 3)

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(eventFlags: CGEventFlags) {
        var value: ShortcutModifiers = []
        if eventFlags.contains(.maskCommand) { value.insert(.command) }
        if eventFlags.contains(.maskShift) { value.insert(.shift) }
        if eventFlags.contains(.maskAlternate) { value.insert(.option) }
        if eventFlags.contains(.maskControl) { value.insert(.control) }
        self = value
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var value: ShortcutModifiers = []
        if eventFlags.contains(.command) { value.insert(.command) }
        if eventFlags.contains(.shift) { value.insert(.shift) }
        if eventFlags.contains(.option) { value.insert(.option) }
        if eventFlags.contains(.control) { value.insert(.control) }
        self = value
    }

    var symbols: String {
        var value = ""
        if contains(.control) { value += "⌃" }
        if contains(.option) { value += "⌥" }
        if contains(.shift) { value += "⇧" }
        if contains(.command) { value += "⌘" }
        return value
    }
}

struct ShortcutDefinition: Codable, Equatable, Sendable {
    let keyCode: UInt16
    let modifiers: ShortcutModifiers

    var displayName: String {
        modifiers.symbols + (KeyCodeNames.names[keyCode] ?? "Key \(keyCode)")
    }

    func matches(keyCode: UInt16, modifiers: ShortcutModifiers) -> Bool {
        self.keyCode == keyCode && self.modifiers == modifiers
    }
}

enum ShortcutCommand: String, CaseIterable, Identifiable {
    case toggleCat
    case showSettings
    case mirrorModel
    case toggleClickThrough
    case toggleAlwaysOnTop

    var id: String { rawValue }

    @MainActor
    func title(language: AppLanguage) -> String {
        switch self {
        case .toggleCat:
            L10n.text("shortcut.showHide", language: language, fallback: "Show/hide")
        case .showSettings:
            L10n.text("shortcut.showSettings", language: language, fallback: "Settings")
        case .mirrorModel:
            L10n.text("shortcut.mirror", language: language, fallback: "Mirror")
        case .toggleClickThrough:
            L10n.text(
                "shortcut.clickThrough",
                language: language,
                fallback: "Click-through"
            )
        case .toggleAlwaysOnTop:
            L10n.text(
                "shortcut.alwaysOnTop",
                language: language,
                fallback: "Always on top"
            )
        }
    }
}

enum ShortcutIdentifier {
    static func motion(model: ModelRecord, motion: ModelMotion) -> String {
        "\(model.id):motion:\(motion.group):\(motion.index)"
    }

    static func expression(model: ModelRecord, expression: ModelExpression) -> String {
        "\(model.id):expression:\(expression.index)"
    }
}

@MainActor
final class GlobalShortcutService {
    private let settings: AppSettings
    private let modelLibrary: ModelLibrary
    private let scene: CatSceneState
    private let showSettings: () -> Void
    private var pressedKeys: Set<UInt16> = []
    private var cancellables: Set<AnyCancellable> = []

    init(
        settings: AppSettings,
        modelLibrary: ModelLibrary,
        scene: CatSceneState,
        showSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.modelLibrary = modelLibrary
        self.scene = scene
        self.showSettings = showSettings
    }

    func start() {
        modelLibrary.$selectedID
            .combineLatest(scene.$motions, scene.$expressions)
            .sink { [weak self] _, _, _ in self?.installDefaultBehaviorShortcuts() }
            .store(in: &cancellables)
    }

    func handle(keyCode: UInt16, isDown: Bool, modifiers: ShortcutModifiers) {
        guard isDown else {
            pressedKeys.remove(keyCode)
            return
        }
        guard pressedKeys.insert(keyCode).inserted else { return }
        guard !settings.isRecordingShortcut else { return }

        for command in ShortcutCommand.allCases {
            if settings.shortcuts[command.id]?.matches(keyCode: keyCode, modifiers: modifiers) == true {
                run(command)
                return
            }
        }

        guard let model = modelLibrary.selectedModel else { return }
        for motion in scene.motions where settings.shortcuts[ShortcutIdentifier.motion(model: model, motion: motion)]?
            .matches(keyCode: keyCode, modifiers: modifiers) == true {
            scene.play(motion)
            return
        }
        for expression in scene.expressions where settings.shortcuts[ShortcutIdentifier.expression(model: model, expression: expression)]?
            .matches(keyCode: keyCode, modifiers: modifiers) == true {
            scene.apply(expression)
            return
        }
    }

    private func run(_ command: ShortcutCommand) {
        switch command {
        case .toggleCat: settings.catVisible.toggle()
        case .showSettings: showSettings()
        case .mirrorModel: settings.mirror.toggle()
        case .toggleClickThrough: settings.clickThrough.toggle()
        case .toggleAlwaysOnTop: settings.alwaysOnTop.toggle()
        }
    }

    private func installDefaultBehaviorShortcuts() {
        guard let model = modelLibrary.selectedModel else { return }
        let identifiers = scene.motions.map { ShortcutIdentifier.motion(model: model, motion: $0) }
            + scene.expressions.map { ShortcutIdentifier.expression(model: model, expression: $0) }
        var shortcuts = settings.shortcuts
        for (index, identifier) in identifiers.enumerated() where shortcuts[identifier] == nil {
            shortcuts[identifier] = BehaviorShortcutFactory.definition(at: index)
        }
        settings.shortcuts = shortcuts
    }
}

enum BehaviorShortcutFactory {
    private static let digits: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
    private static let letters: [UInt16] = [
        12, 13, 14, 15, 17, 16, 32, 34, 31, 35,
        0, 1, 2, 3, 5, 4, 38, 40, 37,
        6, 7, 8, 9, 11, 45, 46,
    ]
    private static let modifierGroups: [ShortcutModifiers] = [
        [.command],
        [.command, .shift],
        [.command, .option],
        [.command, .shift, .option],
    ]

    static func definition(at index: Int) -> ShortcutDefinition? {
        let tiers = modifierGroups.flatMap { modifiers in
            digits.map { ShortcutDefinition(keyCode: $0, modifiers: modifiers) }
        } + modifierGroups.flatMap { modifiers in
            letters.map { ShortcutDefinition(keyCode: $0, modifiers: modifiers) }
        }
        return tiers.indices.contains(index) ? tiers[index] : nil
    }
}

enum KeyCodeNames {
    static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 25: "9", 26: "7", 28: "8", 29: "0", 31: "O", 32: "U",
        24: "=", 27: "-", 30: "]", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 48: "⇥", 49: "␣", 50: "`", 51: "⌫",
        47: ".", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12", 117: "⌦",
        118: "F4", 120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static let functionKeys: Set<UInt16> = [96, 97, 98, 99, 100, 101, 103, 109, 111, 118, 120, 122]

    static let modifierKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
}

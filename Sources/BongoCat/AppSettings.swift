import Combine
import Foundation

enum CatModelMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case standard
    case keyboard
    case gamepad

    var id: String { rawValue }

    @MainActor
    func title(language: AppLanguage) -> String {
        switch self {
        case .standard: L10n.text("model.standard", language: language, fallback: "Standard")
        case .keyboard: L10n.text("model.keyboard", language: language, fallback: "Keyboard")
        case .gamepad: L10n.text("model.gamepad", language: language, fallback: "Gamepad")
        }
    }
}

enum AppAppearance: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    @MainActor
    func title(language: AppLanguage) -> String {
        switch self {
        case .system:
            L10n.text("pages.preference.general.options.auto", language: language, fallback: "System")
        case .light:
            L10n.text("pages.preference.general.options.lightMode", language: language, fallback: "Light")
        case .dark:
            L10n.text("pages.preference.general.options.darkMode", language: language, fallback: "Dark")
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let catVisible = "native.cat.visible"
        static let alwaysOnTop = "native.window.alwaysOnTop"
        static let clickThrough = "native.window.clickThrough"
        static let positionLocked = "native.window.positionLocked"
        static let scale = "native.window.scale"
        static let opacity = "native.window.opacity"
        static let modelMode = "native.model.mode"
        static let mirror = "native.model.mirror"
        static let mouseMirror = "native.model.mouseMirror"
        static let ignoreMouseMovement = "native.model.ignoreMouseMovement"
        static let hideOnHover = "native.window.hideOnHover"
        static let hideOnHoverDelay = "native.window.hideOnHoverDelay"
        static let keepOnScreen = "native.window.keepOnScreen"
        static let cornerRadius = "native.window.cornerRadius"
        static let motionSound = "native.model.motionSound"
        static let behaviorsEnabled = "native.model.behaviorsEnabled"
        static let maximumFramesPerSecond = "native.model.maximumFramesPerSecond"
        static let launchAtLogin = "native.app.launchAtLogin"
        static let showDockIcon = "native.app.showDockIcon"
        static let showMenuBarIcon = "native.app.showMenuBarIcon"
        static let appearance = "native.app.appearance"
        static let language = "native.app.language"
        static let shortcuts = "native.shortcuts"
    }

    private let defaults: UserDefaults

    @Published var catVisible: Bool { didSet { defaults.set(catVisible, forKey: Key.catVisible) } }
    @Published var alwaysOnTop: Bool { didSet { defaults.set(alwaysOnTop, forKey: Key.alwaysOnTop) } }
    @Published var clickThrough: Bool { didSet { defaults.set(clickThrough, forKey: Key.clickThrough) } }
    @Published var positionLocked: Bool {
        didSet { defaults.set(positionLocked, forKey: Key.positionLocked) }
    }
    @Published var scale: Double { didSet { defaults.set(scale, forKey: Key.scale) } }
    @Published var opacity: Double { didSet { defaults.set(opacity, forKey: Key.opacity) } }
    @Published var mirror: Bool { didSet { defaults.set(mirror, forKey: Key.mirror) } }
    @Published var mouseMirror: Bool { didSet { defaults.set(mouseMirror, forKey: Key.mouseMirror) } }
    @Published var ignoreMouseMovement: Bool {
        didSet { defaults.set(ignoreMouseMovement, forKey: Key.ignoreMouseMovement) }
    }
    @Published var hideOnHover: Bool { didSet { defaults.set(hideOnHover, forKey: Key.hideOnHover) } }
    @Published var hideOnHoverDelay: Double {
        didSet { defaults.set(hideOnHoverDelay, forKey: Key.hideOnHoverDelay) }
    }
    @Published var keepOnScreen: Bool { didSet { defaults.set(keepOnScreen, forKey: Key.keepOnScreen) } }
    @Published var cornerRadius: Double { didSet { defaults.set(cornerRadius, forKey: Key.cornerRadius) } }
    @Published var motionSound: Bool { didSet { defaults.set(motionSound, forKey: Key.motionSound) } }
    @Published var behaviorsEnabled: Bool {
        didSet { defaults.set(behaviorsEnabled, forKey: Key.behaviorsEnabled) }
    }
    @Published var maximumFramesPerSecond: Int {
        didSet { defaults.set(maximumFramesPerSecond, forKey: Key.maximumFramesPerSecond) }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }
    @Published var showDockIcon: Bool {
        didSet {
            defaults.set(showDockIcon, forKey: Key.showDockIcon)
            if !showDockIcon && !showMenuBarIcon { showMenuBarIcon = true }
        }
    }
    @Published var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon)
            if !showMenuBarIcon && !showDockIcon { showDockIcon = true }
        }
    }
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }
    @Published var shortcuts: [String: ShortcutDefinition] {
        didSet { defaults.set(try? JSONEncoder().encode(shortcuts), forKey: Key.shortcuts) }
    }
    @Published var isRecordingShortcut = false
    @Published var modelMode: CatModelMode {
        didSet { defaults.set(modelMode.rawValue, forKey: Key.modelMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        catVisible = defaults.object(forKey: Key.catVisible) as? Bool ?? true
        alwaysOnTop = defaults.object(forKey: Key.alwaysOnTop) as? Bool ?? true
        clickThrough = defaults.object(forKey: Key.clickThrough) as? Bool ?? false
        positionLocked = defaults.object(forKey: Key.positionLocked) as? Bool ?? false
        scale = defaults.object(forKey: Key.scale) as? Double ?? 35
        opacity = defaults.object(forKey: Key.opacity) as? Double ?? 100
        mirror = defaults.object(forKey: Key.mirror) as? Bool ?? false
        mouseMirror = defaults.object(forKey: Key.mouseMirror) as? Bool ?? false
        ignoreMouseMovement = defaults.object(forKey: Key.ignoreMouseMovement) as? Bool ?? false
        hideOnHover = defaults.object(forKey: Key.hideOnHover) as? Bool ?? false
        hideOnHoverDelay = defaults.object(forKey: Key.hideOnHoverDelay) as? Double ?? 0
        keepOnScreen = defaults.object(forKey: Key.keepOnScreen) as? Bool ?? true
        cornerRadius = defaults.object(forKey: Key.cornerRadius) as? Double ?? 0
        motionSound = defaults.object(forKey: Key.motionSound) as? Bool ?? true
        behaviorsEnabled = defaults.object(forKey: Key.behaviorsEnabled) as? Bool ?? true
        maximumFramesPerSecond = defaults.object(forKey: Key.maximumFramesPerSecond) as? Int ?? 60
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
        showDockIcon = defaults.object(forKey: Key.showDockIcon) as? Bool ?? false
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        appearance = AppAppearance(
            rawValue: defaults.string(forKey: Key.appearance) ?? "system"
        ) ?? .system
        language = AppLanguage(
            rawValue: defaults.string(forKey: Key.language) ?? ""
        ) ?? AppLanguage.systemDefault()
        shortcuts = defaults.data(forKey: Key.shortcuts)
            .flatMap { try? JSONDecoder().decode([String: ShortcutDefinition].self, from: $0) }
            ?? [:]
        modelMode = CatModelMode(
            rawValue: defaults.string(forKey: Key.modelMode) ?? "standard"
        ) ?? .standard
    }

    func setShortcut(_ shortcut: ShortcutDefinition?, for identifier: String) {
        var updated = shortcuts
        if let shortcut {
            for (key, value) in updated where key != identifier && value == shortcut {
                updated.removeValue(forKey: key)
            }
            updated[identifier] = shortcut
        } else {
            updated.removeValue(forKey: identifier)
        }
        shortcuts = updated
    }
}

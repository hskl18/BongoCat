import Foundation
import Testing
@testable import BongoCat

@Suite("App defaults")
@MainActor
struct AppSettingsTests {
    @Test("A new cat uses a compact scale and exposes smaller menu presets")
    func compactDefaultScale() {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)

        #expect(settings.scale == 35)
        #expect(WindowScalePresets.values == [25, 35, 50, 75, 100, 125, 150])
    }

    @Test("A new cat starts unlocked")
    func startsUnlocked() {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)

        #expect(settings.positionLocked == false)
    }

    @Test("Dock and menu bar controls always leave one recovery path")
    func applicationRecoveryPath() {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(defaults: defaults)

        settings.showMenuBarIcon = false
        #expect(settings.showDockIcon == true)

        settings.showDockIcon = false
        #expect(settings.showMenuBarIcon == true)
    }

    @Test("Shortcut assignments persist and replace conflicts")
    func shortcutPersistenceAndConflicts() throws {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(defaults: defaults)
        let shortcut = ShortcutDefinition(keyCode: 18, modifiers: [.command])

        settings.setShortcut(shortcut, for: ShortcutCommand.toggleCat.id)
        settings.setShortcut(shortcut, for: ShortcutCommand.showSettings.id)

        #expect(settings.shortcuts[ShortcutCommand.toggleCat.id] == nil)
        #expect(settings.shortcuts[ShortcutCommand.showSettings.id] == shortcut)
        #expect(AppSettings(defaults: defaults).shortcuts == settings.shortcuts)
    }

    @Test("Language selection persists independently of the system locale")
    func languagePersistence() {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(defaults: defaults)

        settings.language = .traditionalChinese

        #expect(AppSettings(defaults: defaults).language == .traditionalChinese)
    }
}

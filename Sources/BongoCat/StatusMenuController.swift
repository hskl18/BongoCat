import AppKit
import Combine

enum StatusMenuIcon {
    static func make(resourceURL: URL?) -> NSImage? {
        guard let resourceURL, let image = NSImage(contentsOf: resourceURL) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    static func bundled(bundle: Bundle = .main) -> NSImage? {
        make(resourceURL: bundle.url(forResource: "BongoCatTray", withExtension: "png"))
    }
}

enum WindowScalePresets {
    static let values = [25, 35, 50, 75, 100, 125, 150]
}

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let settings: AppSettings
    private let showPreferences: () -> Void
    private let restart: () -> Void
    private let quit: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []

    init(
        settings: AppSettings,
        showPreferences: @escaping () -> Void,
        restart: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.settings = settings
        self.showPreferences = showPreferences
        self.restart = restart
        self.quit = quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let image = StatusMenuIcon.bundled()
            ?? NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "BongoCat")
        statusItem.button?.image = image
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = "BongoCat"
        menu.delegate = self
        statusItem.menu = menu

        settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.rebuildMenu() }
            }
            .store(in: &cancellables)
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    func makeContextMenu() -> NSMenu {
        let contextMenu = NSMenu()
        populate(contextMenu)
        return contextMenu
    }

    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    private func rebuildMenu() {
        populate(menu)
    }

    private func populate(_ targetMenu: NSMenu) {
        let language = settings.language
        targetMenu.removeAllItems()
        targetMenu.addItem(item(
            L10n.text(
                "composables.useAppMenu.labels.preference",
                language: language,
                fallback: "Settings..."
            ),
            action: #selector(openPreferences),
            key: ","
        ))
        targetMenu.addItem(.separator())
        targetMenu.addItem(toggleItem(
            settings.catVisible
                ? L10n.text(
                    "composables.useAppMenu.labels.hideCat",
                    language: language,
                    fallback: "Hide Cat"
                )
                : L10n.text(
                    "composables.useAppMenu.labels.showCat",
                    language: language,
                    fallback: "Show Cat"
                ),
            action: #selector(toggleCat)
        ))

        let alwaysOnTop = toggleItem(
            L10n.text("menu.keepAbove", language: language, fallback: "Keep Above Other Windows"),
            action: #selector(toggleAlwaysOnTop)
        )
        alwaysOnTop.state = settings.alwaysOnTop ? .on : .off
        targetMenu.addItem(alwaysOnTop)

        let clickThrough = toggleItem(
            L10n.text(
                "composables.useAppMenu.labels.passThrough",
                language: language,
                fallback: "Ignore Pointer Clicks"
            ),
            action: #selector(toggleClickThrough)
        )
        clickThrough.state = settings.clickThrough ? .on : .off
        targetMenu.addItem(clickThrough)

        let positionLocked = toggleItem(
            L10n.text("menu.lock", language: language, fallback: "Lock Cat Position"),
            action: #selector(togglePositionLock)
        )
        positionLocked.state = settings.positionLocked ? .on : .off
        targetMenu.addItem(positionLocked)

        targetMenu.addItem(submenuItem(
            title: L10n.text(
                "composables.useAppMenu.labels.windowSize",
                language: language,
                fallback: "Size"
            ),
            values: WindowScalePresets.values,
            selected: settings.scale,
            action: #selector(setScale(_:))
        ))
        targetMenu.addItem(submenuItem(
            title: L10n.text(
                "composables.useAppMenu.labels.opacity",
                language: language,
                fallback: "Opacity"
            ),
            values: [25, 50, 75, 100],
            selected: settings.opacity,
            action: #selector(setOpacity(_:))
        ))

        targetMenu.addItem(.separator())
        targetMenu.addItem(item(
            L10n.text(
                "menu.sourceCode",
                language: language,
                fallback: "Source Code"
            ),
            action: #selector(openSourceCode)
        ))
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "unknown"
        let versionItem = NSMenuItem(title: "v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        targetMenu.addItem(versionItem)
        targetMenu.addItem(.separator())
        targetMenu.addItem(item(
            L10n.text(
                "composables.useAppMenu.labels.restartApp",
                language: language,
                fallback: "Restart BongoCat"
            ),
            action: #selector(restartApp)
        ))
        targetMenu.addItem(item(
            L10n.text(
                "composables.useAppMenu.labels.quitApp",
                language: language,
                fallback: "Quit BongoCat"
            ),
            action: #selector(quitApp),
            key: "q"
        ))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func toggleItem(_ title: String, action: Selector) -> NSMenuItem {
        item(title, action: action)
    }

    private func submenuItem(
        title: String,
        values: [Int],
        selected: Double,
        action: Selector
    ) -> NSMenuItem {
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        for value in values {
            let option = NSMenuItem(title: "\(value)%", action: action, keyEquivalent: "")
            option.target = self
            option.representedObject = value
            option.state = Int(selected.rounded()) == value ? .on : .off
            submenu.addItem(option)
        }
        root.submenu = submenu
        return root
    }

    @objc private func openPreferences() {
        showPreferences()
    }

    @objc private func toggleCat() {
        settings.catVisible.toggle()
    }

    @objc private func toggleAlwaysOnTop() {
        settings.alwaysOnTop.toggle()
    }

    @objc private func toggleClickThrough() {
        settings.clickThrough.toggle()
    }

    @objc private func togglePositionLock() {
        settings.positionLocked.toggle()
    }

    @objc private func setScale(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        settings.scale = Double(value)
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        settings.opacity = Double(value)
    }

    @objc private func quitApp() {
        quit()
    }

    @objc private func restartApp() {
        restart()
    }

    @objc private func openSourceCode() {
        guard let url = URL(string: "https://github.com/hskl18/BongoCat") else { return }
        NSWorkspace.shared.open(url)
    }
}

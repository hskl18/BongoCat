import AppKit
import Combine
import Foundation

@main
enum BongoCatMain {
    @MainActor
    static func main() {
        if ApplicationRelauncher.runHelperIfRequested() { return }
        guard SingleInstance.acquire() else {
            SingleInstance.showExistingInstance()
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var modelLibrary = ModelLibrary()
    private lazy var scene = CatSceneState(settings: settings, modelLibrary: modelLibrary)
    private let inputMonitor = InputMonitor()
    private let gamepadMonitor = GamepadMonitor()
    private let diagnostics = DiagnosticsService()

    private var catPanel: FloatingCatPanelController?
    private var preferencesWindow: PreferencesWindowController?
    private var statusMenu: StatusMenuController?
    private var lifecycleController: AppLifecycleController?
    private var shortcutService: GlobalShortcutService?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showSettingsFromDuplicateLaunch),
            name: ApplicationNotification.showSettings,
            object: nil
        )
        inputMonitor.onKeyChange = { [weak self] code, isDown in
            self?.scene.handleKey(code: code, isDown: isDown)
        }
        inputMonitor.onShortcutChange = { [weak self] code, isDown, modifiers in
            self?.shortcutService?.handle(keyCode: code, isDown: isDown, modifiers: modifiers)
        }
        inputMonitor.onMouseChange = { [weak self] button, isDown in
            self?.scene.handleMouse(button: button, isDown: isDown)
        }
        inputMonitor.onPointerMove = { [weak self] in
            self?.handlePointerMovement()
        }
        gamepadMonitor.onInput = { [weak self] input, value in
            self?.scene.handleGamepad(input: input, value: value)
        }
        gamepadMonitor.onDisconnect = { [weak self] in
            self?.scene.resetGamepad()
        }
        inputMonitor.$status
            .removeDuplicates()
            .sink { [weak self] status in
                self?.diagnostics.record("Input monitor status: \(status.diagnosticTitle)")
            }
            .store(in: &cancellables)

        preferencesWindow = PreferencesWindowController(
            settings: settings,
            rootView: PreferencesView(
                settings: settings,
                inputMonitor: inputMonitor,
                modelLibrary: modelLibrary,
                scene: scene,
                diagnostics: diagnostics
            )
        )
        shortcutService = GlobalShortcutService(
            settings: settings,
            modelLibrary: modelLibrary,
            scene: scene,
            showSettings: { [weak self] in self?.preferencesWindow?.show() }
        )
        shortcutService?.start()
        statusMenu = StatusMenuController(
            settings: settings,
            showPreferences: { [weak self] in self?.preferencesWindow?.show() },
            restart: { ApplicationRelauncher.restart() },
            quit: { NSApp.terminate(nil) }
        )
        if let statusMenu {
            lifecycleController = AppLifecycleController(
                settings: settings,
                statusMenu: statusMenu
            )
            lifecycleController?.start()
        }
        catPanel = FloatingCatPanelController(
            settings: settings,
            scene: scene,
            contextMenuProvider: { [weak self] in self?.statusMenu?.makeContextMenu() }
        )

        inputMonitor.start(requestAccessIfNeeded: true)
        gamepadMonitor.start()
        diagnostics.record("BongoCat launched.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        diagnostics.record("BongoCat terminated.")
        DistributedNotificationCenter.default().removeObserver(self)
        inputMonitor.stop()
        gamepadMonitor.stop()
        catPanel?.hide()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        inputMonitor.retryIfPermissionRequired()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferencesWindow?.show()
        return true
    }

    private func handlePointerMovement() {
        let location = NSEvent.mouseLocation
        if settings.ignoreMouseMovement {
            scene.resetPointer()
        } else {
            scene.updatePointer(location)
        }
        catPanel?.updatePointerLocation(location)
    }

    @objc private func showSettingsFromDuplicateLaunch() {
        preferencesWindow?.show()
    }
}

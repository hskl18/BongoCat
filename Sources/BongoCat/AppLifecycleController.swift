import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppLifecycleController: ObservableObject {
    @Published private(set) var launchAtLoginError: String?

    private let settings: AppSettings
    private let statusMenu: StatusMenuController
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings, statusMenu: StatusMenuController) {
        self.settings = settings
        self.statusMenu = statusMenu
    }

    func start() {
        settings.launchAtLogin = SMAppService.mainApp.status == .enabled

        settings.$showDockIcon
            .removeDuplicates()
            .sink { visible in
                NSApp.setActivationPolicy(visible ? .regular : .accessory)
            }
            .store(in: &cancellables)

        settings.$showMenuBarIcon
            .removeDuplicates()
            .sink { [weak statusMenu] visible in statusMenu?.setVisible(visible) }
            .store(in: &cancellables)

        settings.$appearance
            .removeDuplicates()
            .sink { appearance in
                NSApp.appearance = switch appearance {
                case .system: nil
                case .light: NSAppearance(named: .aqua)
                case .dark: NSAppearance(named: .darkAqua)
                }
            }
            .store(in: &cancellables)

        settings.$launchAtLogin
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] enabled in self?.setLaunchAtLogin(enabled) }
            .store(in: &cancellables)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            settings.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

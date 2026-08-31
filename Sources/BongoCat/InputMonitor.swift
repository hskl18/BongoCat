import ApplicationServices
import AppKit
import Combine
import Foundation

enum InputMonitorStatus: Equatable {
    case stopped
    case permissionRequired
    case listening
    case failed(String)

    @MainActor
    func title(language: AppLanguage) -> String {
        switch self {
        case .stopped:
            L10n.text("input.stopped", language: language, fallback: "Stopped")
        case .permissionRequired:
            L10n.text(
                "input.permission",
                language: language,
                fallback: "Input Monitoring required"
            )
        case .listening:
            L10n.text("input.listening", language: language, fallback: "Listening")
        case .failed:
            L10n.text("input.unavailable", language: language, fallback: "Unavailable")
        }
    }

    var diagnosticTitle: String {
        switch self {
        case .stopped: "stopped"
        case .permissionRequired: "permission required"
        case .listening: "listening"
        case let .failed(message): "failed - \(message)"
        }
    }
}

enum MonitoredInputEvent: Equatable, Sendable {
    case key(code: UInt16, isDown: Bool, modifiers: ShortcutModifiers)
    case mouse(button: CatMouseButton, isDown: Bool)
    case pointerMoved
    case reenableTap
    case ignored
}

protocol InputAccessAuthorizing {
    func hasAccess() -> Bool
    func requestAccess() -> Bool
}

@MainActor
protocol InputMonitoringSettingsOpening {
    func openInputMonitoringSettings()
}

private struct SystemInputAccessAuthorizer: InputAccessAuthorizing {
    func hasAccess() -> Bool {
        CGPreflightListenEventAccess()
    }

    func requestAccess() -> Bool {
        CGRequestListenEventAccess()
    }
}

@MainActor
private struct SystemInputMonitoringSettingsOpener: InputMonitoringSettingsOpening {
    func openInputMonitoringSettings() {
        let inputMonitoringURL = URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
        )!
        NSWorkspace.shared.open(inputMonitoringURL)

        if let systemSettings = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.systempreferences"
        ).first {
            systemSettings.activate(options: [.activateAllWindows])
        }
    }
}

@MainActor
final class InputMonitor: ObservableObject {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let accessAuthorizer: any InputAccessAuthorizing
    private let settingsOpener: any InputMonitoringSettingsOpening

    @Published private(set) var status: InputMonitorStatus = .stopped

    var onKeyChange: ((UInt16, Bool) -> Void)?
    var onShortcutChange: ((UInt16, Bool, ShortcutModifiers) -> Void)?
    var onMouseChange: ((CatMouseButton, Bool) -> Void)?
    var onPointerMove: (() -> Void)?

    init(
        accessAuthorizer: any InputAccessAuthorizing = SystemInputAccessAuthorizer(),
        settingsOpener: any InputMonitoringSettingsOpening = SystemInputMonitoringSettingsOpener()
    ) {
        self.accessAuthorizer = accessAuthorizer
        self.settingsOpener = settingsOpener
    }

    func start(requestAccessIfNeeded: Bool = false) {
        stop()

        let hasAccess = accessAuthorizer.hasAccess()
            || (requestAccessIfNeeded && accessAuthorizer.requestAccess())
        guard hasAccess else {
            status = .permissionRequired
            return
        }

        let eventTypes: [CGEventType] = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
        ]
        let mask = eventTypes.reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << CGEventMask($1.rawValue))
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: inputEventCallback,
            userInfo: userInfo
        ) else {
            status = .failed("macOS did not create the event tap.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        runLoopSource = source
        status = .listening
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        if status == .listening {
            status = .stopped
        }
    }

    func requestPermission() {
        start(requestAccessIfNeeded: true)
        guard status != .listening else { return }
        settingsOpener.openInputMonitoringSettings()
    }

    func retryIfPermissionRequired() {
        guard status == .permissionRequired else { return }
        start()
    }

    fileprivate func consume(_ input: MonitoredInputEvent) {
        switch input {
        case let .key(code, isDown, modifiers):
            onKeyChange?(code, isDown)
            onShortcutChange?(code, isDown, modifiers)
        case let .mouse(button, isDown):
            onMouseChange?(button, isDown)
        case .pointerMoved:
            onPointerMove?()
        case .reenableTap:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        case .ignored:
            break
        }
    }
}

private let inputEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<InputMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let input = monitoredInput(type: type, event: event)
    MainActor.assumeIsolated {
        monitor.consume(input)
    }
    return Unmanaged.passUnretained(event)
}

func monitoredInput(type: CGEventType, event: CGEvent) -> MonitoredInputEvent {
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    switch type {
    case .keyDown:
        return .key(
            code: keyCode,
            isDown: true,
            modifiers: ShortcutModifiers(eventFlags: event.flags)
        )
    case .keyUp:
        return .key(
            code: keyCode,
            isDown: false,
            modifiers: ShortcutModifiers(eventFlags: event.flags)
        )
    case .flagsChanged:
        return .key(
            code: keyCode,
            isDown: modifierIsDown(keyCode: keyCode, flags: event.flags),
            modifiers: ShortcutModifiers(eventFlags: event.flags)
        )
    case .leftMouseDown:
        return .mouse(button: .left, isDown: true)
    case .leftMouseUp:
        return .mouse(button: .left, isDown: false)
    case .rightMouseDown:
        return .mouse(button: .right, isDown: true)
    case .rightMouseUp:
        return .mouse(button: .right, isDown: false)
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
        return .pointerMoved
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        return .reenableTap
    default:
        return .ignored
    }
}

private func modifierIsDown(keyCode: UInt16, flags: CGEventFlags) -> Bool {
    switch keyCode {
    case 55, 54: flags.contains(.maskCommand)
    case 56, 60: flags.contains(.maskShift)
    case 58, 61: flags.contains(.maskAlternate)
    case 59, 62: flags.contains(.maskControl)
    case 57: flags.contains(.maskAlphaShift)
    case 63: flags.contains(.maskSecondaryFn)
    default: false
    }
}

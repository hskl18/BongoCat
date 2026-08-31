import ApplicationServices
import Testing
@testable import BongoCat

@Suite("Input monitoring permission")
@MainActor
struct InputMonitorTests {
    @Test("First launch requests Input Monitoring when access is missing")
    func firstLaunchRequestsPermission() {
        let access = RefusingInputAccessAuthorizer()
        let monitor = InputMonitor(
            accessAuthorizer: access,
            settingsOpener: RecordingInputMonitoringSettingsOpener()
        )

        monitor.start(requestAccessIfNeeded: true)

        #expect(access.requestCount == 1)
        #expect(monitor.status == .permissionRequired)
    }

    @Test("The permission action always opens the exact System Settings page")
    func permissionActionOpensSystemSettings() {
        let opener = RecordingInputMonitoringSettingsOpener()
        let monitor = InputMonitor(
            accessAuthorizer: RefusingInputAccessAuthorizer(),
            settingsOpener: opener
        )

        monitor.requestPermission()

        #expect(opener.openCount == 1)
        #expect(monitor.status == .permissionRequired)
    }

    @Test("A Core Graphics left click keeps its button identity")
    func mapsLeftMouseDown() throws {
        let event = try #require(CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: .zero,
            mouseButton: .left
        ))

        let input = monitoredInput(type: .leftMouseDown, event: event)

        #expect(input == .mouse(button: .left, isDown: true))
    }

    @Test("A Core Graphics key press keeps its virtual key code")
    func mapsKeyDown() throws {
        let event = try #require(CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0,
            keyDown: true
        ))
        event.flags = []

        let input = monitoredInput(type: .keyDown, event: event)

        #expect(input == .key(code: 0, isDown: true, modifiers: []))
    }

    @Test("A Core Graphics key press preserves shortcut modifiers")
    func mapsKeyModifiers() throws {
        let event = try #require(CGEvent(
            keyboardEventSource: nil,
            virtualKey: 18,
            keyDown: true
        ))
        event.flags = [.maskCommand, .maskShift]

        let input = monitoredInput(type: .keyDown, event: event)

        #expect(input == .key(
            code: 18,
            isDown: true,
            modifiers: [.command, .shift]
        ))
    }

    @Test("Pointer movement becomes an event instead of a polling tick")
    func mapsPointerMovement() throws {
        let event = try #require(CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: CGPoint(x: 120, y: 80),
            mouseButton: .left
        ))

        let input = monitoredInput(type: .mouseMoved, event: event)

        #expect(input == .pointerMoved)
    }
}

private final class RefusingInputAccessAuthorizer: InputAccessAuthorizing {
    private(set) var requestCount = 0

    func hasAccess() -> Bool { false }

    func requestAccess() -> Bool {
        requestCount += 1
        return false
    }
}

@MainActor
private final class RecordingInputMonitoringSettingsOpener: InputMonitoringSettingsOpening {
    private(set) var openCount = 0

    func openInputMonitoringSettings() {
        openCount += 1
    }
}

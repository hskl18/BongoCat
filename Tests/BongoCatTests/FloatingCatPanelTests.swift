import AppKit
import Testing
@testable import BongoCat

@Suite("Floating cat panel", .serialized)
@MainActor
struct FloatingCatPanelTests {
    @Test("A size change applies the new percentage immediately")
    func sizeChangeUsesNewValue() {
        _ = NSApplication.shared
        let defaults = makeDefaults()
        defaults.set(50.0, forKey: "native.window.scale")
        let settings = AppSettings(defaults: defaults)
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        }

        settings.scale = 75

        #expect(panel?.frame.size.width == 459)
        #expect(panel?.frame.size.height == 266)
        controller.hide()
        panel?.close()
    }

    @Test("Native edge resizing preserves aspect ratio and persists the derived scale")
    func nativeEdgeResizePersistsScale() throws {
        _ = NSApplication.shared
        let settings = AppSettings(defaults: makeDefaults())
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = try #require(NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        })

        panel.setContentSize(NSSize(width: 306, height: 177))

        #expect(settings.scale == 50)
        #expect(abs(panel.frame.width / panel.frame.height - 612.0 / 354.0) < 0.001)
        controller.hide()
        panel.close()
    }

    @Test("The cat surface can drag its window")
    func catSurfaceAllowsWindowDragging() {
        _ = NSApplication.shared
        let settings = AppSettings(defaults: makeDefaults())
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        }

        let contentViewType = panel?.contentView.map { String(describing: type(of: $0)) }
        #expect(contentViewType?.contains("DraggableHostingView") == true)
        #expect(panel?.contentView?.mouseDownCanMoveWindow == true)
        controller.hide()
        panel?.close()
    }

    @Test("An opacity change applies the new percentage immediately")
    func opacityChangeUsesNewValue() {
        _ = NSApplication.shared
        let defaults = makeDefaults()
        defaults.set(25.0, forKey: "native.window.opacity")
        let settings = AppSettings(defaults: defaults)
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        }

        settings.opacity = 75

        #expect(panel?.alphaValue == 0.75)
        controller.hide()
        panel?.close()
    }

    @Test("Changing always-on-top applies immediately")
    func alwaysOnTopChangeUsesNewValue() {
        _ = NSApplication.shared
        let settings = AppSettings(defaults: makeDefaults())
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        }

        settings.alwaysOnTop = false

        #expect(panel?.level == .normal)
        controller.hide()
        panel?.close()
    }

    @Test("Changing click-through applies immediately")
    func clickThroughChangeUsesNewValue() {
        _ = NSApplication.shared
        let settings = AppSettings(defaults: makeDefaults())
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        }

        settings.clickThrough = true

        #expect(panel?.ignoresMouseEvents == true)
        #expect(panel?.isMovableByWindowBackground == false)
        controller.hide()
        panel?.close()
    }

    @Test("Enabling screen containment immediately brings the cat on screen")
    func keepOnScreenChangeUsesNewValue() throws {
        _ = NSApplication.shared
        let defaults = makeDefaults()
        defaults.set(false, forKey: "native.window.keepOnScreen")
        let settings = AppSettings(defaults: defaults)
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = try #require(NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        })
        let visibleFrame = try #require(NSScreen.main?.visibleFrame)
        panel.setFrameOrigin(NSPoint(x: visibleFrame.maxX + 200, y: visibleFrame.minY))

        settings.keepOnScreen = true

        #expect(panel.frame.maxX <= visibleFrame.maxX)
        controller.hide()
        panel.close()
    }

    @Test("Locking the cat disables dragging until it is unlocked")
    func positionLockControlsDragging() throws {
        _ = NSApplication.shared
        let settings = AppSettings(defaults: makeDefaults())
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = try #require(NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        })
        let dragSurface = try #require(panel.contentView as? any WindowDraggingSurface)

        settings.positionLocked = true
        #expect(dragSurface.isDragEnabled == false)
        #expect(panel.isMovableByWindowBackground == false)
        #expect(!panel.styleMask.contains(.resizable))

        settings.positionLocked = false
        #expect(dragSurface.isDragEnabled == true)
        #expect(panel.isMovableByWindowBackground == true)
        #expect(panel.styleMask.contains(.resizable))
        controller.hide()
        panel.close()
    }

    @Test("Hover delay hides even when the pointer stops moving")
    func delayedHoverHide() async throws {
        _ = NSApplication.shared
        let defaults = makeDefaults()
        defaults.set(true, forKey: "native.window.hideOnHover")
        defaults.set(0.05, forKey: "native.window.hideOnHoverDelay")
        let settings = AppSettings(defaults: defaults)
        let scene = CatSceneState(settings: settings)
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = FloatingCatPanelController(settings: settings, scene: scene)
        let panel = try #require(NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0 is NSPanel
        })
        panel.setFrameOrigin(NSPoint(x: NSEvent.mouseLocation.x - 20, y: NSEvent.mouseLocation.y - 20))

        controller.updatePointerLocation(NSEvent.mouseLocation)
        try await Task.sleep(for: .milliseconds(100))

        #expect(panel.alphaValue == 0)
        #expect(panel.ignoresMouseEvents)
        controller.updatePointerLocation(NSPoint(x: panel.frame.maxX + 20, y: panel.frame.maxY + 20))
        #expect(abs(Double(panel.alphaValue) - settings.opacity / 100) < 0.000_001)
        controller.hide()
        panel.close()
    }

    @Test("Shift-right dragging resizes proportionally and clamps the scale")
    func resizeGestureScale() {
        #expect(PanelResizeGesture.scale(
            from: 35,
            startPointer: NSPoint(x: 100, y: 100),
            currentPointer: NSPoint(x: 120, y: 80)
        ) == 55)
        #expect(PanelResizeGesture.scale(
            from: 35,
            startPointer: .zero,
            currentPointer: NSPoint(x: -1_000, y: 1_000)
        ) == 10)
        #expect(PanelResizeGesture.scale(
            from: 35,
            startPointer: .zero,
            currentPointer: NSPoint(x: 1_000, y: -1_000)
        ) == 500)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

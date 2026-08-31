import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingCatPanelController: NSObject {
    private enum PositionKey {
        static let x = "native.window.position.x"
        static let y = "native.window.position.y"
    }

    private static let modelSize = NSSize(width: 612, height: 354)

    private let panel: NSPanel
    private let settings: AppSettings
    private var cancellables: Set<AnyCancellable> = []
    private var hoverWorkItem: DispatchWorkItem?
    private var hiddenForHover = false
    private var isApplyingScale = false

    init(
        settings: AppSettings,
        scene: CatSceneState,
        contextMenuProvider: @escaping @MainActor () -> NSMenu? = { nil }
    ) {
        self.settings = settings
        let initialSize = Self.scaledSize(settings.scale)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        let contentView = DraggableHostingView(
            rootView: CatCanvasView(settings: settings, scene: scene)
        )
        contentView.contextMenuProvider = contextMenuProvider
        contentView.currentScale = { settings.scale }
        contentView.setScale = { settings.scale = $0 }
        panel.contentView = contentView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .utilityWindow
        panel.contentAspectRatio = Self.modelSize
        panel.contentMinSize = Self.scaledSize(10)
        panel.contentMaxSize = Self.scaledSize(500)

        restorePosition(orFor: initialSize)
        bindSettings()
        observeMoves()
        applyAllSettings()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func updatePointerLocation(_ point: NSPoint) {
        guard settings.hideOnHover else {
            cancelHoverWork()
            setHiddenForHover(false)
            return
        }

        guard panel.frame.contains(point) else {
            cancelHoverWork()
            setHiddenForHover(false)
            return
        }

        guard hoverWorkItem == nil, !hiddenForHover else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  settings.hideOnHover,
                  panel.frame.contains(NSEvent.mouseLocation)
            else { return }
            hoverWorkItem = nil
            setHiddenForHover(true)
        }
        hoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(settings.hideOnHoverDelay, 0),
            execute: workItem
        )
    }

    private func bindSettings() {
        settings.$catVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                if !visible {
                    self?.cancelHoverWork()
                    self?.setHiddenForHover(false)
                }
                visible ? self?.show() : self?.hide()
            }
            .store(in: &cancellables)

        settings.$alwaysOnTop
            .removeDuplicates()
            .sink { [weak self] alwaysOnTop in self?.applyWindowLevel(alwaysOnTop) }
            .store(in: &cancellables)

        settings.$clickThrough
            .removeDuplicates()
            .sink { [weak self] clickThrough in
                self?.applyPointerInteraction(clickThrough: clickThrough)
            }
            .store(in: &cancellables)

        settings.$positionLocked
            .removeDuplicates()
            .sink { [weak self] positionLocked in
                self?.applyPointerInteraction(positionLocked: positionLocked)
            }
            .store(in: &cancellables)

        settings.$opacity
            .removeDuplicates()
            .sink { [weak self] opacity in self?.applyOpacity(opacity) }
            .store(in: &cancellables)

        settings.$scale
            .removeDuplicates()
            .sink { [weak self] scale in self?.applyScale(scale) }
            .store(in: &cancellables)

        settings.$hideOnHover
            .removeDuplicates()
            .sink { [weak self] enabled in
                if !enabled {
                    self?.cancelHoverWork()
                    self?.setHiddenForHover(false)
                } else {
                    self?.updatePointerLocation(NSEvent.mouseLocation)
                }
            }
            .store(in: &cancellables)

        settings.$hideOnHoverDelay
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, settings.hideOnHover else { return }
                cancelHoverWork()
                updatePointerLocation(NSEvent.mouseLocation)
            }
            .store(in: &cancellables)

        settings.$keepOnScreen
            .removeDuplicates()
            .sink { [weak self] keepOnScreen in
                self?.clampToVisibleScreen(whenEnabled: keepOnScreen)
            }
            .store(in: &cancellables)
    }

    private func observeMoves() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: panel
        )
    }

    @objc private func panelDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        clampToVisibleScreen()
        UserDefaults.standard.set(window.frame.origin.x, forKey: PositionKey.x)
        UserDefaults.standard.set(window.frame.origin.y, forKey: PositionKey.y)
    }

    @objc private func panelDidResize(_ notification: Notification) {
        guard !isApplyingScale,
              let window = notification.object as? NSWindow
        else { return }
        let scale = ((window.frame.width / Self.modelSize.width) * 100)
            .rounded()
            .clamped(to: 10 ... 500)
        if settings.scale != scale {
            settings.scale = scale
        }
    }

    private func applyAllSettings() {
        applyWindowLevel()
        applyPointerInteraction()
        applyOpacity()
        if settings.catVisible {
            show()
        }
    }

    private func applyWindowLevel(_ alwaysOnTop: Bool? = nil) {
        panel.level = (alwaysOnTop ?? settings.alwaysOnTop) ? .floating : .normal
    }

    private func applyPointerInteraction(
        clickThrough: Bool? = nil,
        positionLocked: Bool? = nil
    ) {
        let ignoresMouseEvents = (clickThrough ?? settings.clickThrough) || hiddenForHover
        let allowsDragging = !ignoresMouseEvents && !(positionLocked ?? settings.positionLocked)
        panel.ignoresMouseEvents = ignoresMouseEvents
        panel.isMovableByWindowBackground = allowsDragging
        if allowsDragging {
            panel.styleMask.insert(.resizable)
        } else {
            panel.styleMask.remove(.resizable)
        }
        (panel.contentView as? any WindowDraggingSurface)?.isDragEnabled = allowsDragging
    }

    private func applyOpacity(_ opacity: Double? = nil) {
        panel.alphaValue = hiddenForHover ? 0 : (opacity ?? settings.opacity) / 100
    }

    private func applyScale(_ scale: Double) {
        let nextSize = Self.scaledSize(scale)
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let origin = NSPoint(x: center.x - nextSize.width / 2, y: center.y - nextSize.height / 2)
        isApplyingScale = true
        panel.setFrame(NSRect(origin: origin, size: nextSize), display: true, animate: false)
        isApplyingScale = false
        clampToVisibleScreen()
    }

    private func setHiddenForHover(_ hidden: Bool) {
        guard hiddenForHover != hidden else { return }
        hiddenForHover = hidden
        applyOpacity()
        applyPointerInteraction()
    }

    private func cancelHoverWork() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

    private func clampToVisibleScreen(whenEnabled keepOnScreen: Bool? = nil) {
        guard keepOnScreen ?? settings.keepOnScreen else { return }
        let currentFrame = panel.frame
        let screen = panel.screen
            ?? NSScreen.screens.max(by: {
                $0.visibleFrame.intersection(currentFrame).area
                    < $1.visibleFrame.intersection(currentFrame).area
            })
            ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - currentFrame.width)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - currentFrame.height)
        let origin = NSPoint(
            x: min(max(currentFrame.minX, visibleFrame.minX), maximumX),
            y: min(max(currentFrame.minY, visibleFrame.minY), maximumY)
        )
        guard origin != currentFrame.origin else { return }
        panel.setFrameOrigin(origin)
    }

    private func restorePosition(orFor size: NSSize) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PositionKey.x) != nil,
           defaults.object(forKey: PositionKey.y) != nil {
            let origin = NSPoint(
                x: defaults.double(forKey: PositionKey.x),
                y: defaults.double(forKey: PositionKey.y)
            )
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(NSRect(origin: origin, size: size)) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }

        let frame = NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(PanelGeometry.defaultOrigin(visibleFrame: frame, panelSize: size))
    }

    private static func scaledSize(_ scale: Double) -> NSSize {
        let ratio = max(10, min(scale, 500)) / 100
        return NSSize(width: modelSize.width * ratio, height: modelSize.height * ratio)
    }
}

enum PanelGeometry {
    static func defaultOrigin(
        visibleFrame: NSRect,
        panelSize: NSSize,
        padding: CGFloat = 24
    ) -> NSPoint {
        NSPoint(
            x: visibleFrame.maxX - panelSize.width - padding,
            y: visibleFrame.minY + padding
        )
    }
}

enum PanelResizeGesture {
    static func scale(
        from startScale: Double,
        startPointer: NSPoint,
        currentPointer: NSPoint
    ) -> Double {
        let horizontal = currentPointer.x - startPointer.x
        let vertical = startPointer.y - currentPointer.y
        return (startScale + (horizontal + vertical) * 0.5)
            .rounded()
            .clamped(to: 10 ... 500)
    }
}

@MainActor
protocol WindowDraggingSurface: AnyObject {
    var isDragEnabled: Bool { get set }
}

@MainActor
private final class DraggableHostingView<Content: View>: NSHostingView<Content>, WindowDraggingSurface {
    var isDragEnabled = true
    var contextMenuProvider: @MainActor () -> NSMenu? = { nil }
    var currentScale: @MainActor () -> Double = { 100 }
    var setScale: @MainActor (Double) -> Void = { _ in }

    private var resizeStartPointer: NSPoint?
    private var resizeStartScale = 100.0

    override var mouseDownCanMoveWindow: Bool { isDragEnabled }

    override func mouseDown(with event: NSEvent) {
        guard isDragEnabled else { return }
        window?.performDrag(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        event.modifierFlags.contains(.shift) ? nil : contextMenuProvider()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.shift) else {
            super.rightMouseDown(with: event)
            return
        }
        guard isDragEnabled else { return }
        resizeStartPointer = NSEvent.mouseLocation
        resizeStartScale = currentScale()
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard isDragEnabled, let resizeStartPointer else { return }
        setScale(PanelResizeGesture.scale(
            from: resizeStartScale,
            startPointer: resizeStartPointer,
            currentPointer: NSEvent.mouseLocation
        ))
    }

    override func rightMouseUp(with event: NSEvent) {
        resizeStartPointer = nil
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

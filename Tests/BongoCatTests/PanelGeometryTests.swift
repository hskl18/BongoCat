import AppKit
import Testing
@testable import BongoCat

@Suite("Default cat position")
struct PanelGeometryTests {
    @Test("A new cat starts in the lower-right corner")
    func defaultOriginIsLowerRight() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let catSize = NSSize(width: 306, height: 177)

        let origin = PanelGeometry.defaultOrigin(
            visibleFrame: visibleFrame,
            panelSize: catSize
        )

        #expect(origin == NSPoint(x: 1_110, y: 24))
    }
}

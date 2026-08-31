import AppKit
import Foundation
import Testing
@testable import BongoCat

@Suite("Menu bar icon")
struct StatusMenuIconTests {
    @Test("The BongoCat artwork is prepared at menu-bar size")
    func preparesBongoCatArtwork() throws {
        let nativeRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let artworkURL = nativeRoot
            .appendingPathComponent("Resources/BongoCatTray.png")

        let image = try #require(StatusMenuIcon.make(resourceURL: artworkURL))

        #expect(image.size == NSSize(width: 18, height: 18))
        #expect(image.isTemplate == false)
    }
}

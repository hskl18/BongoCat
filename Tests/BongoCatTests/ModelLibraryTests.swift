import Foundation
import Testing
@testable import BongoCat

@Suite("Custom model library", .serialized)
@MainActor
struct ModelLibraryTests {
    @Test("Import validates, copies, selects, and restores a custom model")
    func importAndRestore() async throws {
        let suiteName = "BongoCatTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BongoCatTests.\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }
        let library = ModelLibrary(defaults: defaults, bundle: .main, customRoot: root)

        try await library.importModels(from: [modelsRoot.appendingPathComponent("gamepad")])

        let imported = try #require(library.selectedModel)
        #expect(imported.isPreset == false)
        #expect(imported.mode == .gamepad)
        #expect(FileManager.default.fileExists(atPath: imported.directoryURL.path))

        let restored = ModelLibrary(defaults: defaults, bundle: .main, customRoot: root)
        #expect(restored.selectedModel?.id == imported.id)
        #expect(restored.selectedModel?.directoryURL == imported.directoryURL)
    }

    private var modelsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Models", isDirectory: true)
    }
}

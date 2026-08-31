import Foundation
import Testing
@testable import BongoCat

@Suite("Application diagnostics")
@MainActor
struct DiagnosticsTests {
    @Test("Application logs are bounded and remain writable")
    func boundedLogFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BongoCatTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let logURL = root.appendingPathComponent("BongoCat.log")
        try Data(repeating: 65, count: 1_100_000).write(to: logURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let diagnostics = DiagnosticsService(baseURL: root)
        diagnostics.record("rotation test")

        let attributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
        let size = try #require(attributes[.size] as? NSNumber).intValue
        #expect(size < 300_000)
        let text = try String(contentsOf: logURL, encoding: .utf8)
        #expect(text.contains("rotation test"))
    }
}

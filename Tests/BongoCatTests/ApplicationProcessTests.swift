import Foundation
import Testing
@testable import BongoCat

@Suite("Application process lifecycle")
struct ApplicationProcessTests {
    @Test("Relaunch helper arguments preserve the exact application path")
    func parsesRelaunchArguments() throws {
        let request = try #require(RelaunchRequest.parse(arguments: [
            "BongoCat",
            "--relaunch-after",
            "4242",
            "/Applications/BongoCat.app",
        ]))

        #expect(request.processID == 4242)
        #expect(request.applicationURL.path == "/Applications/BongoCat.app")
    }

    @Test("The instance lock rejects a second owner and recovers after release")
    func exclusiveInstanceLock() throws {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BongoCatTests.\(UUID().uuidString).lock")
        var first: InstanceLock? = InstanceLock()
        let second = InstanceLock()

        #expect(first?.acquire(at: lockURL) == true)
        #expect(second.acquire(at: lockURL) == false)
        first = nil
        #expect(second.acquire(at: lockURL) == true)
        try? FileManager.default.removeItem(at: lockURL)
    }
}

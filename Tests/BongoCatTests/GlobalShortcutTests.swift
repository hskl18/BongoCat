import Testing
@testable import BongoCat

@Suite("Global shortcuts")
struct GlobalShortcutTests {
    @Test("Behavior shortcuts follow the upstream Command-number sequence")
    func upstreamBehaviorSequence() {
        #expect(BehaviorShortcutFactory.definition(at: 0) == ShortcutDefinition(
            keyCode: 18,
            modifiers: [.command]
        ))
        #expect(BehaviorShortcutFactory.definition(at: 9) == ShortcutDefinition(
            keyCode: 29,
            modifiers: [.command]
        ))
        #expect(BehaviorShortcutFactory.definition(at: 10) == ShortcutDefinition(
            keyCode: 18,
            modifiers: [.command, .shift]
        ))
    }
}

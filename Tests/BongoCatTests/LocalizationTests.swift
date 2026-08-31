import Foundation
import Testing
@testable import BongoCat

@Suite("Five-language localization")
@MainActor
struct LocalizationTests {
    @Test("Every upstream locale contains every native mapped key")
    func upstreamLocaleCoverage() throws {
        let nativeRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for language in AppLanguage.allCases {
            let url = nativeRoot
                .appendingPathComponent("Resources/Locales", isDirectory: true)
                .appendingPathComponent("\(language.rawValue).json")
            let catalog = try LocaleCatalog.load(from: url)
            let missing = L10n.requiredUpstreamKeys.subtracting(catalog.values.keys)
            #expect(missing.isEmpty, "\(language.rawValue) is missing \(missing.sorted())")
        }
    }

    @Test("Every native-only phrase is translated in all five languages")
    func nativeLocaleCoverage() throws {
        let englishKeys = try #require(L10n.extra[.english]).keys
        for language in AppLanguage.allCases {
            let values = try #require(L10n.extra[language])
            #expect(Set(values.keys) == Set(englishKeys))
            #expect(values.values.allSatisfy { !$0.isEmpty })
        }
    }

    @Test("System language selection distinguishes both Chinese scripts")
    func systemLanguageSelection() {
        #expect(AppLanguage.systemDefault(preferredLanguages: ["zh-Hans-US"]) == .simplifiedChinese)
        #expect(AppLanguage.systemDefault(preferredLanguages: ["zh-Hant-TW"]) == .traditionalChinese)
        #expect(AppLanguage.systemDefault(preferredLanguages: ["vi-VN"]) == .vietnamese)
        #expect(AppLanguage.systemDefault(preferredLanguages: ["pt-PT"]) == .portuguese)
    }
}

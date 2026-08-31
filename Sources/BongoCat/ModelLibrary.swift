import AppKit
import Foundation

struct ModelRecord: Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let mode: CatModelMode
    let isPreset: Bool
    let directoryURL: URL
}

@MainActor
final class ModelLibrary: ObservableObject {
    private enum Key {
        static let catalog = "native.model.customCatalog"
        static let selectedID = "native.model.selectedID"
    }

    @Published private(set) var models: [ModelRecord]
    @Published var selectedID: String {
        didSet { defaults.set(selectedID, forKey: Key.selectedID) }
    }

    private let defaults: UserDefaults
    private let customRoot: URL

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        customRoot: URL? = nil
    ) {
        self.defaults = defaults
        self.customRoot = customRoot ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BongoCat/Models", isDirectory: true)
        let builtInRoot = bundle.resourceURL?.appendingPathComponent("Models", isDirectory: true)
        let presets = CatModelMode.allCases.compactMap { mode -> ModelRecord? in
            guard let directory = builtInRoot?.appendingPathComponent(mode.rawValue, isDirectory: true),
                  FileManager.default.fileExists(atPath: directory.path)
            else { return nil }
            return ModelRecord(
                id: "preset.\(mode.rawValue)",
                name: mode.rawValue.capitalized,
                mode: mode,
                isPreset: true,
                directoryURL: directory
            )
        }
        let custom = Self.loadPersisted(defaults: defaults, root: self.customRoot)
        models = presets + custom
        let saved = defaults.string(forKey: Key.selectedID)
        selectedID = (presets + custom).contains { $0.id == saved }
            ? saved!
            : presets.first?.id ?? "preset.standard"
    }

    var selectedModel: ModelRecord? {
        models.first { $0.id == selectedID } ?? models.first
    }

    func select(_ model: ModelRecord) {
        selectedID = model.id
    }

    func importModels(from sourceURLs: [URL]) async throws {
        for sourceURL in sourceURLs {
            let root = customRoot
            let record = try await Task.detached(priority: .userInitiated) {
                try Self.importModel(from: sourceURL, to: root)
            }.value
            models.append(record)
            selectedID = record.id
            persist()
        }
    }

    func reveal(_ model: ModelRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([model.directoryURL])
    }

    func delete(_ model: ModelRecord) throws {
        guard !model.isPreset else { return }
        var resultingURL: NSURL?
        try FileManager.default.trashItem(
            at: model.directoryURL,
            resultingItemURL: &resultingURL
        )
        models.removeAll { $0.id == model.id }
        if selectedID == model.id {
            selectedID = models.first?.id ?? "preset.standard"
        }
        persist()
    }

    private func persist() {
        let records = models.filter { !$0.isPreset }.map {
            PersistedModel(id: $0.id, name: $0.name, mode: $0.mode)
        }
        defaults.set(try? JSONEncoder().encode(records), forKey: Key.catalog)
    }

    private nonisolated static func importModel(from sourceURL: URL, to root: URL) throws -> ModelRecord {
        _ = try ModelManifest.load(from: sourceURL)
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let id = UUID().uuidString.lowercased()
        let temporaryURL = root.appendingPathComponent(".import-\(id)", isDirectory: true)
        let destinationURL = root.appendingPathComponent(id, isDirectory: true)
        do {
            try manager.copyItem(at: sourceURL, to: temporaryURL)
            let manifest = try ModelManifest.load(from: temporaryURL)
            try manager.moveItem(at: temporaryURL, to: destinationURL)
            return ModelRecord(
                id: id,
                name: sourceURL.lastPathComponent,
                mode: manifest.detectedMode,
                isPreset: false,
                directoryURL: destinationURL
            )
        } catch {
            if manager.fileExists(atPath: temporaryURL.path) {
                try? manager.removeItem(at: temporaryURL)
            }
            throw error
        }
    }

    private static func loadPersisted(defaults: UserDefaults, root: URL) -> [ModelRecord] {
        guard let data = defaults.data(forKey: Key.catalog),
              let records = try? JSONDecoder().decode([PersistedModel].self, from: data)
        else { return [] }
        return records.compactMap { record in
            let directory = root.appendingPathComponent(record.id, isDirectory: true)
            guard FileManager.default.fileExists(atPath: directory.path),
                  (try? ModelManifest.load(from: directory)) != nil
            else { return nil }
            return ModelRecord(
                id: record.id,
                name: record.name,
                mode: record.mode,
                isPreset: false,
                directoryURL: directory
            )
        }
    }

    private struct PersistedModel: Codable {
        let id: String
        let name: String
        let mode: CatModelMode
    }
}

import Foundation

struct ModelMotion: Identifiable, Hashable, Sendable {
    let group: String
    let index: Int
    let fileURL: URL
    let soundURL: URL?

    var id: String { "\(group):\(index)" }
}

struct ModelExpression: Identifiable, Hashable, Sendable {
    let index: Int
    let name: String
    let fileURL: URL

    var id: String { "\(index):\(name)" }
}

struct ModelManifest: Sendable {
    let settingsURL: URL
    let mocURL: URL
    let textureURLs: [URL]
    let physicsURL: URL?
    let poseURL: URL?
    let motions: [ModelMotion]
    let expressions: [ModelExpression]
    let coverURL: URL?
    let detectedMode: CatModelMode

    static func load(from directory: URL) throws -> ModelManifest {
        let manager = FileManager.default
        let settingsURL = try manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ).first { $0.lastPathComponent.hasSuffix(".model3.json") }
        guard let settingsURL else { throw ModelManifestError.settingsMissing }

        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let settings = try decoder.decode(Settings.self, from: Data(contentsOf: settingsURL))
        let mocURL = try resolve(settings.fileReferences.moc, inside: directory)
        let textureURLs = try settings.fileReferences.textures.map {
            try resolve($0, inside: directory)
        }
        let physicsURL = try settings.fileReferences.physics.map {
            try resolve($0, inside: directory)
        }
        let poseURL = try settings.fileReferences.pose.map {
            try resolve($0, inside: directory)
        }
        let motions = try (settings.fileReferences.motions ?? [:]).flatMap { group, items in
            try items.enumerated().map { index, item in
                ModelMotion(
                    group: group,
                    index: index,
                    fileURL: try resolve(item.file, inside: directory),
                    soundURL: try item.sound.map { try resolve($0, inside: directory) }
                )
            }
        }
        let expressions = try (settings.fileReferences.expressions ?? []).enumerated().map {
            index, item in
            ModelExpression(
                index: index,
                name: item.name,
                fileURL: try resolve(item.file, inside: directory)
            )
        }
        let cover = directory.appendingPathComponent("resources/cover.png")
        return ModelManifest(
            settingsURL: settingsURL,
            mocURL: mocURL,
            textureURLs: textureURLs,
            physicsURL: physicsURL,
            poseURL: poseURL,
            motions: motions.sorted { ($0.group, $0.index) < ($1.group, $1.index) },
            expressions: expressions,
            coverURL: manager.fileExists(atPath: cover.path) ? cover : nil,
            detectedMode: detectMode(in: directory)
        )
    }

    private static func resolve(_ relativePath: String, inside directory: URL) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
            throw ModelManifestError.unsafeReference(relativePath)
        }
        let root = directory.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        let url = directory
            .appendingPathComponent(relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard url.path.hasPrefix(root), FileManager.default.fileExists(atPath: url.path) else {
            throw ModelManifestError.unsafeReference(relativePath)
        }
        return url
    }

    private static func detectMode(in directory: URL) -> CatModelMode {
        let rightKeys = directory.appendingPathComponent("resources/right-keys", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: rightKeys.path)) ?? []
        if names.contains(where: { $0 == "East.png" }) { return .gamepad }
        return names.isEmpty ? .standard : .keyboard
    }

    private struct Settings: Decodable {
        let fileReferences: FileReferences

        enum CodingKeys: String, CodingKey {
            case fileReferences = "FileReferences"
        }
    }

    private struct FileReferences: Decodable {
        let moc: String
        let textures: [String]
        let physics: String?
        let pose: String?
        let motions: [String: [Motion]]?
        let expressions: [Expression]?

        enum CodingKeys: String, CodingKey {
            case moc = "Moc"
            case textures = "Textures"
            case physics = "Physics"
            case pose = "Pose"
            case motions = "Motions"
            case expressions = "Expressions"
        }
    }

    private struct Motion: Decodable {
        let file: String
        let sound: String?

        enum CodingKeys: String, CodingKey {
            case file = "File"
            case sound = "Sound"
        }
    }

    private struct Expression: Decodable {
        let name: String
        let file: String

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case file = "File"
        }
    }
}

enum ModelManifestError: LocalizedError {
    case settingsMissing
    case unsafeReference(String)

    var errorDescription: String? {
        switch self {
        case .settingsMissing:
            "No .model3.json file was found."
        case let .unsafeReference(path):
            "The model reference is missing or outside its directory: \(path)"
        }
    }
}

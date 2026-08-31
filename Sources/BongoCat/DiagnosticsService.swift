import AppKit
import Foundation
import OSLog

@MainActor
final class DiagnosticsService {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.local.BongoCatNative",
        category: "Application"
    )

    let logURL: URL

    init(baseURL: URL? = nil) {
        let root = baseURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BongoCat/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        logURL = root.appendingPathComponent("BongoCat.log")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
           let size = attributes[.size] as? NSNumber,
           size.intValue > 1_000_000,
           let data = try? Data(contentsOf: logURL) {
            try? Data(data.suffix(256_000)).write(to: logURL, options: .atomic)
        }
        if !FileManager.default.fileExists(atPath: logURL.path) {
            _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }

    func record(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        guard let data = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: logURL)
        else { return }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            try? handle.close()
        }
    }

    func copyApplicationInformation(
        inputStatus: InputMonitorStatus,
        selectedModel: ModelRecord?
    ) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            applicationInformation(inputStatus: inputStatus, selectedModel: selectedModel),
            forType: .string
        )
    }

    func applicationInformation(
        inputStatus: InputMonitorStatus,
        selectedModel: ModelRecord?
    ) -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let architecture = ProcessInfo.processInfo.machineArchitecture
        return [
            "BongoCat \(version) (\(build))",
            "Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Architecture: \(architecture)",
            "Renderer: Cubism Core + Metal",
            "Input monitoring: \(inputStatus.diagnosticTitle)",
            "Model: \(selectedModel?.name ?? "unknown")",
        ].joined(separator: "\n")
    }

    func revealLogs() {
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }

}

private extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

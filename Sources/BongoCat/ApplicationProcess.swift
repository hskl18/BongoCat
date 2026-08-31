import AppKit
import Darwin
import Foundation

enum ApplicationNotification {
    static let showSettings = Notification.Name("com.local.BongoCat.showSettings")
}

final class InstanceLock {
    private var descriptor: Int32 = -1

    func acquire(at url: URL) -> Bool {
        guard descriptor == -1 else { return true }
        let fileDescriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else { return false }
        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(fileDescriptor)
            return false
        }
        descriptor = fileDescriptor
        return true
    }

    deinit {
        if descriptor >= 0 {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
    }
}

@MainActor
enum SingleInstance {
    private static let lock = InstanceLock()

    static func acquire() -> Bool {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.local.BongoCat.instance.lock")
        return lock.acquire(at: lockURL)
    }

    static func showExistingInstance() {
        DistributedNotificationCenter.default().postNotificationName(
            ApplicationNotification.showSettings,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

struct RelaunchRequest: Equatable {
    let processID: pid_t
    let applicationURL: URL

    static func parse(arguments: [String]) -> RelaunchRequest? {
        guard arguments.count == 4,
              arguments[1] == "--relaunch-after",
              let processID = pid_t(arguments[2]),
              processID > 0
        else { return nil }
        return RelaunchRequest(
            processID: processID,
            applicationURL: URL(fileURLWithPath: arguments[3]).standardizedFileURL
        )
    }
}

enum ApplicationRelauncher {
    static func runHelperIfRequested(arguments: [String] = CommandLine.arguments) -> Bool {
        guard let request = RelaunchRequest.parse(arguments: arguments) else { return false }

        let deadline = Date().addingTimeInterval(15)
        while processExists(request.processID), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard !processExists(request.processID) else { return true }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", request.applicationURL.path]
        try? process.run()
        return true
    }

    @MainActor
    static func restart() {
        guard let executableURL = Bundle.main.executableURL else { return }
        let applicationURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--relaunch-after",
            String(ProcessInfo.processInfo.processIdentifier),
            applicationURL.path,
        ]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            NSSound.beep()
        }
    }

    private static func processExists(_ processID: pid_t) -> Bool {
        if kill(processID, 0) == 0 { return true }
        return errno == EPERM
    }
}

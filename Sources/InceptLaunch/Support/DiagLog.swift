import Foundation

enum DiagLog {
    private static let maxFileSize: UInt64 = 10 * 1024 * 1024 // 10 MB

    /// Master on/off switch, mirrored from `UserPreferences.diagLoggingEnabled`.
    /// Defaults to on so a first-run crash/hang still leaves evidence; call
    /// `configure(enabled:)` once preferences are loaded, and again whenever
    /// the user flips the Settings > About toggle. `write` is called from
    /// both the main actor and the background scan task, hence the lock.
    private final class EnabledBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value = true

        var isEnabled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func set(_ newValue: Bool) {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }

    private static let enabledBox = EnabledBox()

    static var isEnabled: Bool { enabledBox.isEnabled }

    static func configure(enabled: Bool) {
        enabledBox.set(enabled)
    }

    /// True when running under `swift test` (SwiftPM's swift-testing runner
    /// process). Without this, every test run — including ones that
    /// deliberately construct broken/empty scans, fake bundle ids, etc. —
    /// wrote real-looking entries into the SAME production log file the
    /// shipped app uses, making the log useless as evidence of what actually
    /// happened on a user's machine.
    private static let isRunningTests: Bool = {
        ProcessInfo.processInfo.processName == "swiftpm-testing-helper"
    }()

    private static var logURL: URL? {
        guard let dir = try? InceptLaunchPaths.applicationSupportDirectory() else { return nil }
        let logsDir = dir.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent("incept_diag.log")
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func write(_ message: String) {
        guard !isRunningTests else { return }
        guard isEnabled else { return }
        guard let url = logURL else { return }
        let ts = timestampFormatter.string(from: Date())
        let line = "[\(ts)] \(message)\n"

        rotateIfNeeded(url)

        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: url)
        }
    }

    static var logFileURL: URL? { logURL }

    private static func rotateIfNeeded(_ url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64,
              size >= maxFileSize else { return }

        // Keep the most recent half, discard the oldest entries.
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        let kept = lines.suffix(lines.count / 2).joined(separator: "\n")
        try? kept.data(using: .utf8)?.write(to: url)
    }
}

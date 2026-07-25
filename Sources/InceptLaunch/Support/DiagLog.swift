import Foundation

enum DiagLog {
    private static let maxFileSize: UInt64 = 10 * 1024 * 1024 // 10 MB

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

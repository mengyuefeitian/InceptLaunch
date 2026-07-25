import Foundation

enum DiagLog {
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("incept_diag.log")

    static func write(_ message: String) {
        let line = "\(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: url)
        }
    }
}

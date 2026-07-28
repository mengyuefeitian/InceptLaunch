import Foundation
import Testing
@testable import InceptLaunch

private struct Payload: Codable, Equatable {
    var value: String
}

/// Regression safety net: a bug in code that decides what to persist (e.g.
/// the app-scan pruning bugs fixed elsewhere) can still overwrite good data
/// with bad data — the write itself isn't wrong, what's being written is.
/// Keeping one rotating backup of the previous file means that class of bug
/// is always recoverable, not just the specific ones we've found so far.
@Test func saveBacksUpThePreviousFileBeforeOverwriting() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-store-\(UUID().uuidString).json")
    let backupURL = url.appendingPathExtension("bak")
    let store = JSONFileStore<Payload>(url: url)

    try store.save(Payload(value: "first"))
    #expect(!FileManager.default.fileExists(atPath: backupURL.path), "no backup yet — this is the first save")

    try store.save(Payload(value: "second"))
    #expect(FileManager.default.fileExists(atPath: backupURL.path))
    let backedUp = try JSONDecoder.inceptLaunch.decode(Payload.self, from: Data(contentsOf: backupURL))
    #expect(backedUp.value == "first", "the backup must hold the PREVIOUS value, not the one just written")

    let current = try store.load(default: Payload(value: "missing"))
    #expect(current.value == "second")

    try? FileManager.default.removeItem(at: url)
    try? FileManager.default.removeItem(at: backupURL)
}

@Test func saveWithNoExistingFileDoesNotCreateABackup() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-store-\(UUID().uuidString).json")
    let backupURL = url.appendingPathExtension("bak")
    let store = JSONFileStore<Payload>(url: url)

    try store.save(Payload(value: "only"))

    #expect(!FileManager.default.fileExists(atPath: backupURL.path))

    try? FileManager.default.removeItem(at: url)
}

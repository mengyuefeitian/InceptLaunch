import Foundation
import Testing
@testable import InceptLaunch

@Test func scannerReadsMinimalAppBundle() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let appURL = root.appendingPathComponent("Example.app", isDirectory: true)
    let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist = contents.appendingPathComponent("Info.plist")
    try """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>com.example.Example</string>
      <key>CFBundleName</key>
      <string>Example</string>
      <key>CFBundleShortVersionString</key>
      <string>2.5</string>
    </dict>
    </plist>
    """.data(using: .utf8)!.write(to: plist)

    let scanner = AppScanner(finderNameProvider: { _ in nil })
    let records = scanner.scan(
        directories: [root],
        now: Date(timeIntervalSince1970: 20)
    )

    #expect(records.count == 1)
    #expect(records[0].id == "bundle:com.example.Example")
    #expect(records[0].name == "Example")
    #expect(records[0].version == "2.5")
    #expect(records[0].isMissing == false)
}

@Test func scannerPrefersFinderDisplayNameOverBundleName() throws {
    let root = try makeSyntheticApp(name: "Example", bundleName: "WeChat")
    // Two identical bundles (e.g. WeChat.app and WeChat2.app) share the same
    // CFBundleDisplayName; only the Finder/Spotlight name keeps them apart.
    let scanner = AppScanner(finderNameProvider: { url in
        url.lastPathComponent == "Example.app" ? "微信" : nil
    })

    let records = scanner.scan(directories: [root], now: Date(timeIntervalSince1970: 20))

    #expect(records.count == 1)
    #expect(records[0].name == "微信")
}

@Test func scannerStripsAppSuffixFromFinderDisplayName() throws {
    let root = try makeSyntheticApp(name: "Example", bundleName: "WeChat")
    let scanner = AppScanner(finderNameProvider: { _ in "WeChat2.app" })

    let records = scanner.scan(directories: [root], now: Date(timeIntervalSince1970: 20))

    #expect(records.count == 1)
    #expect(records[0].name == "WeChat2")
}

@Test func scannerFallsBackToBundleNameWhenFinderNameUnavailable() throws {
    let root = try makeSyntheticApp(name: "Example", bundleName: "FallbackName")
    let scanner = AppScanner(finderNameProvider: { _ in nil })

    let records = scanner.scan(directories: [root], now: Date(timeIntervalSince1970: 20))

    #expect(records.count == 1)
    #expect(records[0].name == "FallbackName")
}

/// Regression test: AppScanner used to silently swallow FileManager errors
/// per directory (`try?`), contributing zero records for that directory with
/// no signal that anything went wrong. A caller merging that into an
/// existing layout (pruneApps) could not tell "this directory legitimately
/// has no apps" from "this directory failed to enumerate" — and treated
/// both the same, wiping any layout entries that happened to live in the
/// failed directory even though every OTHER configured directory scanned
/// fine. The scan must report which directories failed so callers can
/// distinguish the two cases.
@Test func scanReportsFailedDirectoriesWithoutLosingOtherResults() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let appURL = root.appendingPathComponent("Example.app", isDirectory: true)
    let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    try """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>com.example.Example</string>
      <key>CFBundleName</key>
      <string>Example</string>
    </dict>
    </plist>
    """.data(using: .utf8)!.write(to: contents.appendingPathComponent("Info.plist"))

    let missingDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("does-not-exist-\(UUID().uuidString)")

    let scanner = AppScanner()
    let result = scanner.scanAll(directories: [root, missingDirectory])

    #expect(result.records.count == 1, "the directory that scanned fine must still contribute its apps")
    #expect(result.failedDirectories == [missingDirectory.path])
}

/// Creates a temp directory containing one synthetic `.app` bundle whose
/// `CFBundleName` can differ from the file name.
private func makeSyntheticApp(name: String, bundleName: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let appURL = root.appendingPathComponent("\(name).app", isDirectory: true)
    let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist = contents.appendingPathComponent("Info.plist")
    try """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>com.example.\(name)</string>
      <key>CFBundleName</key>
      <string>\(bundleName)</string>
    </dict>
    </plist>
    """.data(using: .utf8)!.write(to: plist)
    return root
}

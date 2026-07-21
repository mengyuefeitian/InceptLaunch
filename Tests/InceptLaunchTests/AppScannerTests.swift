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

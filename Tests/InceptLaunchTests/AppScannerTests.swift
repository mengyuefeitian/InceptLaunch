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

    let scanner = AppScanner()
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

import Foundation
import Testing
@testable import InceptLaunch

@Test func exactPrefixRanksBeforeSubstring() {
    let records = [
        record("Calendar"),
        record("Super Calendar"),
        record("Calculator")
    ]
    let results = SearchMatcher().ranked(query: "cal", records: records)
    #expect(results.map(\.name) == ["Calculator", "Calendar", "Super Calendar"])
}

private func record(_ name: String) -> AppRecord {
    AppRecord(
        id: "bundle:com.example.\(name)",
        bundleID: "com.example.\(name)",
        name: name,
        localizedName: name,
        path: "/Applications/\(name).app",
        iconCacheKey: name,
        version: nil,
        source: .localApplications,
        isHidden: false,
        isMissing: false,
        lastSeenAt: Date(timeIntervalSince1970: 1),
        lastLaunchedAt: nil
    )
}

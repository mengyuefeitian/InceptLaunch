import Foundation
import Testing
@testable import iLaunch

@Test func mergeMarksMissingWithoutDeletingExistingRecord() {
    let now = Date(timeIntervalSince1970: 100)
    let old = AppRecord(
        id: "bundle:com.example.Editor",
        bundleID: "com.example.Editor",
        name: "Editor",
        localizedName: nil,
        path: "/Applications/Editor.app",
        iconCacheKey: "bundle:com.example.Editor",
        version: "1.0",
        source: .localApplications,
        isHidden: false,
        isMissing: false,
        lastSeenAt: now,
        lastLaunchedAt: nil
    )
    var store = AppIndexStore(records: [old.id: old])
    store.merge(scanResults: [], now: Date(timeIntervalSince1970: 200))
    #expect(store.records[old.id]?.isMissing == true)
    #expect(store.records[old.id]?.name == "Editor")
}

import Foundation

struct AppIndexStore {
    private(set) var records: [String: AppRecord]

    init(records: [String: AppRecord] = [:]) {
        self.records = records
    }

    mutating func merge(scanResults: [AppRecord], now: Date = Date()) {
        let scannedIDs = Set(scanResults.map(\.id))

        for result in scanResults {
            var merged = result
            if let existing = records[result.id] {
                merged.isHidden = existing.isHidden
                merged.lastLaunchedAt = existing.lastLaunchedAt
            }
            records[result.id] = merged
        }

        for id in records.keys where !scannedIDs.contains(id) {
            records[id]?.isMissing = true
        }
    }

    func visibleRecords(hiddenIDs: Set<String>) -> [AppRecord] {
        records.values
            .filter { !$0.isHidden }
            .filter { !hiddenIDs.contains($0.id) }
            .filter { !$0.isMissing }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

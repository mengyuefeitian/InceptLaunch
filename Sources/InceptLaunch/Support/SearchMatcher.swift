import Foundation

struct SearchMatcher {
    func ranked(query: String, records: [AppRecord]) -> [AppRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return records.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return records.compactMap { record -> (AppRecord, Int)? in
            let name = record.name.lowercased()
            let bundleID = record.bundleID?.lowercased() ?? ""
            let score: Int

            if name == normalizedQuery {
                score = 0
            } else if name.hasPrefix(normalizedQuery) {
                score = 1
            } else if bundleID.hasPrefix(normalizedQuery) {
                score = 2
            } else if name.contains(normalizedQuery) {
                score = 3
            } else if bundleID.contains(normalizedQuery) {
                score = 4
            } else {
                return nil
            }

            return (record, score)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending
        }
        .map(\.0)
    }
}

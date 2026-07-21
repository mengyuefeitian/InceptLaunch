import Foundation

struct SearchMatcher {
    private let pinyin = PinyinIndex()

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
                // Pinyin fallback: lets "jisuanqi" or "jsq" match 计算器.
                let index = pinyin.index(for: record.name)
                if index.full.hasPrefix(normalizedQuery) {
                    score = 5
                } else if index.initials.hasPrefix(normalizedQuery) {
                    score = 6
                } else if index.full.contains(normalizedQuery) {
                    score = 7
                } else {
                    return nil
                }
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

/// Transliterates app names to Latin pinyin (via CoreFoundation) so Chinese
/// names can be matched by typing pinyin or its initials. Results are cached by
/// name; the transform is relatively expensive and search runs on every
/// keystroke.
final class PinyinIndex: @unchecked Sendable {
    private var storage: [String: (full: String, initials: String)] = [:]
    private let lock = NSLock()

    func index(for name: String) -> (full: String, initials: String) {
        lock.lock()
        if let hit = storage[name] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let computed = Self.transform(name)

        lock.lock()
        storage[name] = computed
        lock.unlock()
        return computed
    }

    private static func transform(_ name: String) -> (full: String, initials: String) {
        let mutable = NSMutableString(string: name) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latin = (mutable as String).lowercased()
        let full = latin.filter { !$0.isWhitespace }
        let initials = latin
            .split(whereSeparator: \.isWhitespace)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        return (full, initials)
    }
}

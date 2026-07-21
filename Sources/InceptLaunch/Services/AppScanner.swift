import Foundation

struct AppScanner {
    func scan(directories: [URL], now: Date = Date()) -> [AppRecord] {
        directories.flatMap { scan(directory: $0, now: now) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scan(directory: URL, now: Date) -> [AppRecord] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> AppRecord? in
            guard let url = item as? URL, url.pathExtension == "app" else { return nil }
            return record(for: url, now: now)
        }
    }

    private func record(for appURL: URL, now: Date) -> AppRecord? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        let bundleID = plist["CFBundleIdentifier"] as? String
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let id = bundleID.map { "bundle:\($0)" } ?? "path:\(appURL.path)"
        let source = source(for: appURL)

        return AppRecord(
            id: id,
            bundleID: bundleID,
            name: name,
            localizedName: name,
            path: appURL.path,
            iconCacheKey: id,
            version: plist["CFBundleShortVersionString"] as? String,
            source: source,
            isHidden: false,
            isMissing: false,
            lastSeenAt: now,
            lastLaunchedAt: nil
        )
    }

    private func source(for appURL: URL) -> AppRecord.Source {
        if appURL.path.hasPrefix("/System/") { return .systemApplications }
        if appURL.path.hasPrefix(NSHomeDirectory()) { return .userApplications }
        if appURL.path.hasPrefix("/Applications") { return .localApplications }
        return .customDirectory
    }
}

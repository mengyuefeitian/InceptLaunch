import AppKit
import Foundation

/// The result of a full scan: every discovered app record plus any on-disk
/// folders that group multiple apps (e.g. `/Applications/Python 3.13`).
struct ScanResult: Equatable {
    var records: [AppRecord]
    var directoryFolders: [DirectoryFolder]
}

struct AppScanner {
    /// Flat list of every discovered app, sorted by display name.
    func scan(directories: [URL], now: Date = Date()) -> [AppRecord] {
        scanAll(directories: directories, now: now).records
    }

    /// Full scan: app records plus detected multi-app directories.
    func scanAll(directories: [URL], now: Date = Date()) -> ScanResult {
        var collected: [AppRecord] = []
        var folderGroups: [(dirURL: URL, memberPaths: [String])] = []

        for directory in directories {
            collect(from: directory, into: &collected, folderGroups: &folderGroups, now: now)
        }

        // Assign stable, unique ids. A bundle identifier is used when it is
        // unique across the scan; when several bundles share one (e.g. IDLE in
        // both Python 3.13 and 3.14) each instance falls back to a path-based
        // id so they stay distinct. Duplicate ids previously produced blank
        // cells because SwiftUI's ForEach requires unique identifiers.
        var bundleIDCounts: [String: Int] = [:]
        for record in collected {
            if let bundleID = record.bundleID {
                bundleIDCounts[bundleID, default: 0] += 1
            }
        }

        var records: [AppRecord] = []
        var pathToID: [String: String] = [:]
        for var record in collected {
            let finalID: String
            if let bundleID = record.bundleID, bundleIDCounts[bundleID] == 1 {
                finalID = "bundle:\(bundleID)"
            } else {
                finalID = "path:\(record.path)"
            }
            record.id = finalID
            record.iconCacheKey = finalID
            pathToID[record.path] = finalID
            records.append(record)
        }

        records.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var directoryFolders: [DirectoryFolder] = []
        for group in folderGroups {
            let memberIDs = group.memberPaths.compactMap { pathToID[$0] }
            guard memberIDs.count >= 2 else { continue }
            directoryFolders.append(DirectoryFolder(
                id: "dir:\(group.dirURL.path)",
                name: group.dirURL.lastPathComponent,
                path: group.dirURL.path,
                appIDs: memberIDs
            ))
        }
        directoryFolders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return ScanResult(records: records, directoryFolders: directoryFolders)
    }

    private func collect(
        from directory: URL,
        into collected: inout [AppRecord],
        folderGroups: inout [(dirURL: URL, memberPaths: [String])],
        now: Date
    ) {
        // System trees are scanned flat so utilities keep appearing
        // individually, matching the native Launchpad.
        let isSystem = directory.path.hasPrefix("/System")

        if isSystem {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return }
            for item in enumerator {
                guard let url = item as? URL, url.pathExtension == "app" else { continue }
                if let record = record(for: url, now: now) {
                    collected.append(record)
                }
            }
            return
        }

        // Non-system trees are scanned top-level so a directory holding
        // several apps (Python 3.13) can be grouped into a folder, while a
        // directory holding a single app (Adobe Photoshop 2025) just surfaces
        // that app directly.
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for entry in entries {
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }

            if entry.pathExtension == "app" {
                if let record = record(for: entry, now: now) {
                    collected.append(record)
                }
            } else {
                var memberPaths: [String] = []
                if let enumerator = FileManager.default.enumerator(
                    at: entry,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for item in enumerator {
                        guard let url = item as? URL, url.pathExtension == "app" else { continue }
                        if let record = record(for: url, now: now) {
                            collected.append(record)
                            memberPaths.append(url.path)
                        }
                    }
                }
                if !memberPaths.isEmpty {
                    folderGroups.append((entry, memberPaths))
                }
            }
        }
    }

    private func record(for appURL: URL, now: Date) -> AppRecord? {
        // `Bundle` understands both macOS bundles (`Contents/Info.plist`) and
        // iOS apps running on Apple Silicon (root `Info.plist`), and exposes
        // the localized display name shown by Finder/Launchpad. Reading the
        // raw plist missed iOS apps entirely and showed generic names such as
        // "MediaCenter" instead of "VidHub".
        if let bundle = Bundle(url: appURL),
           let info = bundle.infoDictionary ?? bundle.localizedInfoDictionary {
            let localized = bundle.localizedInfoDictionary ?? [:]
            let name = displayName(localized: localized, base: info, fallback: appURL.deletingPathExtension().lastPathComponent)
            let version = (info["CFBundleShortVersionString"] as? String)
                ?? (localized["CFBundleShortVersionString"] as? String)
            return AppRecord(
                id: "path:\(appURL.path)",
                bundleID: bundle.bundleIdentifier,
                name: name,
                localizedName: name,
                path: appURL.path,
                iconCacheKey: "path:\(appURL.path)",
                version: version,
                source: source(for: appURL),
                isHidden: false,
                isMissing: false,
                lastSeenAt: now,
                lastLaunchedAt: nil
            )
        }
        return recordViaRawPlist(for: appURL, now: now)
    }

    private func displayName(localized: [String: Any], base: [String: Any], fallback: String) -> String {
        let candidates = [
            localized["CFBundleDisplayName"] as? String,
            base["CFBundleDisplayName"] as? String,
            localized["CFBundleName"] as? String,
            base["CFBundleName"] as? String
        ]
        for candidate in candidates {
            if let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return fallback
    }

    /// Fallback for bundles `Bundle` cannot read (keeps synthetic test bundles
    /// and unusual layouts working).
    private func recordViaRawPlist(for appURL: URL, now: Date) -> AppRecord? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        let data = (try? Data(contentsOf: infoURL))
            ?? (try? Data(contentsOf: appURL.appendingPathComponent("Info.plist")))
        guard let data,
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        let bundleID = plist["CFBundleIdentifier"] as? String
        let name = displayName(localized: [:], base: plist, fallback: appURL.deletingPathExtension().lastPathComponent)

        return AppRecord(
            id: "path:\(appURL.path)",
            bundleID: bundleID,
            name: name,
            localizedName: name,
            path: appURL.path,
            iconCacheKey: "path:\(appURL.path)",
            version: plist["CFBundleShortVersionString"] as? String,
            source: source(for: appURL),
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

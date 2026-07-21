import Foundation

struct AppRecord: Codable, Equatable, Identifiable {
    enum Source: String, Codable, Equatable {
        case systemApplications
        case userApplications
        case localApplications
        case customDirectory
        case externalVolume
    }

    var id: String
    var bundleID: String?
    var name: String
    var localizedName: String?
    var path: String
    var iconCacheKey: String
    var version: String?
    var source: Source
    var isHidden: Bool
    var isMissing: Bool
    var lastSeenAt: Date
    var lastLaunchedAt: Date?
}

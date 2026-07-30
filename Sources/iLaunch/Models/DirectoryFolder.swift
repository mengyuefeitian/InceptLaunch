import Foundation

/// A directory on disk (for example `/Applications/Python 3.13`) that contains
/// multiple app bundles and is surfaced as a single folder in the launchpad,
/// mirroring how Finder shows it. Distinct from a user-created
/// `LaunchpadFolder`, which is purely a layout concept.
struct DirectoryFolder: Codable, Equatable {
    var id: String
    var name: String
    var path: String
    var appIDs: [String]
}

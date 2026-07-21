import Foundation

struct LaunchpadFolder: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var items: [String]
    var createdAt: Date
    var updatedAt: Date
}

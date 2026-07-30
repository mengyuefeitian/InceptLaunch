import Foundation

enum LaunchpadItem: Codable, Equatable, Identifiable {
    case app(String)
    case folder(String)

    var id: String {
        switch self {
        case .app(let id): return "app:\(id)"
        case .folder(let id): return "folder:\(id)"
        }
    }
}

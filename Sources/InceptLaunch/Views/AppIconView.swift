import SwiftUI

struct AppIconView: View {
    let item: LaunchpadDisplayItem

    var body: some View {
        VStack(spacing: 8) {
            icon
                .font(.system(size: 54))
                .frame(width: 72, height: 72)
            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 112, height: 112)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        switch item.kind {
        case .app:
            return Image(systemName: "app.fill")
                .foregroundStyle(.primary)
        case .folder:
            return Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
        }
    }
}

import AppKit
import SwiftUI

struct AppIconView: View {
    let item: LaunchpadDisplayItem

    var body: some View {
        VStack(spacing: 8) {
            iconView
                .frame(width: 72, height: 72)
            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .frame(width: 112, height: 112)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.kind {
        case .app(let record):
            RealAppIcon(record: record)
        case .folder:
            Image(systemName: "folder.fill")
                .font(.system(size: 54))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

struct RealAppIcon: View {
    let record: AppRecord
    @State private var nsImage: NSImage?

    var body: some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .task(id: record.iconCacheKey) {
            nsImage = await AppIconCache.shared.icon(for: record)
        }
    }
}

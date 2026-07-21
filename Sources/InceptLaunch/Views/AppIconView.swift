import AppKit
import SwiftUI

struct AppIconView: View {
    let item: LaunchpadDisplayItem

    var body: some View {
        VStack(spacing: 10) {
            iconView
                .frame(width: 104, height: 104)
            Text(item.title)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .frame(width: 132, height: 150)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.kind {
        case .app(let record):
            RealAppIcon(record: record)
        case .folder:
            Image(systemName: "folder.fill")
                .font(.system(size: 76))
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

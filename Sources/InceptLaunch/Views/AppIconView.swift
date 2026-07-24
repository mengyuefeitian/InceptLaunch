import AppKit
import SwiftUI

struct AppIconView: View {
    let item: LaunchpadDisplayItem
    var iconSize: CGFloat = 104
    var tileHeight: CGFloat = 150
    var showHiddenBadge: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            iconView
                .frame(width: iconSize, height: iconSize)
                .overlay(alignment: .bottomTrailing) {
                    if showHiddenBadge {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Circle().fill(.black.opacity(0.55)))
                            .offset(x: 2, y: 2)
                    }
                }
            Text(item.title)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .frame(width: 132, height: tileHeight)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.kind {
        case .app(let record):
            RealAppIcon(record: record)
        case .folder:
            FolderTileView(members: item.members)
        }
    }
}

/// Launchpad-style folder tile: a frosted rounded square showing up to a 2x2
/// preview of the contained apps' icons.
struct FolderTileView: View {
    let members: [AppRecord]

    private var preview: [AppRecord] { Array(members.prefix(4)) }

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.clear)
            .liquidGlass(cornerRadius: 24, fallbackOpacity: 0.16)
            .overlay(
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        cell(0)
                        cell(1)
                    }
                    GridRow {
                        cell(2)
                        cell(3)
                    }
                }
            )
    }

    @ViewBuilder
    private func cell(_ index: Int) -> some View {
        if index < preview.count {
            RealAppIcon(record: preview[index])
                .frame(width: 40, height: 40)
        } else {
            Color.clear.frame(width: 40, height: 40)
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

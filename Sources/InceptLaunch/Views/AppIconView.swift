import AppKit
import SwiftUI

struct AppIconView: View {
    let item: LaunchpadDisplayItem
    var iconSize: CGFloat = 104
    var tileWidth: CGFloat = 132
    var tileHeight: CGFloat = 150
    var showHiddenBadge: Bool = false
    var iconScale: CGFloat = 1.0
    var showName: Bool = true
    /// Only icon + title activate. Blank padding inside the tile dismisses.
    var onActivate: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: ((DragGesture.Value) -> Void)? = nil

    /// When embedded in FolderPopupView, all handlers are nil — do NOT attach
    /// empty DragGesture/onTap or they steal the popup's reorder / drag-out.
    private var handlesGridDrag: Bool {
        onDragChanged != nil || onDragEnded != nil
    }

    var body: some View {
        VStack(spacing: showName ? 10 : 0) {
            interactiveIcon
            if showName {
                interactiveTitle
            }
        }
        // Layout reserves the full cell; no full-tile contentShape so blank
        // padding falls through to page-level dismiss.
        .frame(width: tileWidth, height: tileHeight)
    }

    private var interactiveIcon: some View {
        iconView
            .frame(width: iconSize * iconScale, height: iconSize * iconScale)
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
            .frame(width: iconSize, height: iconSize)
            .contentShape(Rectangle())
            .modifier(OptionalIconGestures(
                onActivate: onActivate,
                onLongPress: onLongPress,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded,
                attachDrag: handlesGridDrag
            ))
    }

    private var interactiveTitle: some View {
        Text(item.title)
            .font(.callout)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .modifier(OptionalIconGestures(
                onActivate: onActivate,
                onLongPress: onLongPress,
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded,
                attachDrag: handlesGridDrag
            ))
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.kind {
        case .app(let record):
            RealAppIcon(record: record)
        case .folder:
            FolderTileView(members: item.members, size: iconSize * iconScale)
        }
    }
}

/// Attaches tap / long-press / drag only when the corresponding handlers exist.
/// Empty DragGesture must not be installed — it blocks parent gestures (folder popup).
private struct OptionalIconGestures: ViewModifier {
    var onActivate: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onDragChanged: ((DragGesture.Value) -> Void)?
    var onDragEnded: ((DragGesture.Value) -> Void)?
    var attachDrag: Bool

    func body(content: Content) -> some View {
        var view: AnyView = AnyView(content)
        if let onActivate {
            view = AnyView(view.onTapGesture { onActivate() })
        }
        if let onLongPress {
            view = AnyView(view.simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4, maximumDistance: 6)
                    .onEnded { _ in onLongPress() }
            ))
        }
        if attachDrag {
            view = AnyView(view.gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named("overlay"))
                    .onChanged { value in onDragChanged?(value) }
                    .onEnded { value in onDragEnded?(value) }
            ))
        }
        return view
    }
}

/// Launchpad-style folder tile: a frosted rounded square showing up to a 2x2
/// preview of the contained apps' icons.
struct FolderTileView: View {
    let members: [AppRecord]
    var size: CGFloat = 104

    private var preview: [AppRecord] { Array(members.prefix(4)) }
    private var cellSize: CGFloat { size * 0.36 }
    private var gridSpacing: CGFloat { size * 0.06 }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(.white.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .overlay(
                Grid(horizontalSpacing: gridSpacing, verticalSpacing: gridSpacing) {
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
                .frame(width: cellSize, height: cellSize)
        } else {
            Color.clear.frame(width: cellSize, height: cellSize)
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

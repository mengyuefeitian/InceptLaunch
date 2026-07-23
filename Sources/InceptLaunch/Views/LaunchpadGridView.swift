import SwiftUI

struct LaunchpadGridView: View {
    let pages: [[LaunchpadDisplayItem]]
    let rows: Int
    let enlargedFolderIDs: Set<String>
    let onLaunch: (LaunchpadDisplayItem) -> Void
    let onDropItem: (String, LaunchpadDisplayItem) -> Void
    let onTrash: (LaunchpadDisplayItem) -> Void
    let onEnlarge: (LaunchpadDisplayItem) -> Void
    let onShrink: (LaunchpadDisplayItem) -> Void
    let onDismiss: () -> Void

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { geo in
                let width = geo.size.width
                // Enlarged folders span 2×2 = 4 cells (3 extra each); the row
                // estimate must account for them or the grid overflows vertically.
                let maxPageRows = pages.map { page -> Int in
                    let enlargedCount = page.filter { enlargedFolderIDs.contains($0.id) }.count
                    let effectiveCells = page.count + enlargedCount * 3
                    return (effectiveCells + GridMetrics.columns - 1) / GridMetrics.columns
                }.max() ?? 1
                let sizingRows = max(rows, maxPageRows)
                let fitted = (geo.size.height - CGFloat(sizingRows - 1) * GridMetrics.rowSpacing) / CGFloat(sizingRows)
                let tileHeight = min(GridMetrics.tileHeight, max(96, fitted))
                let iconSize = GridMetrics.iconSize * (tileHeight / GridMetrics.tileHeight)
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageGrid(pages[index], iconSize: iconSize, tileHeight: tileHeight)
                            .frame(width: width, height: geo.size.height, alignment: .center)
                    }
                }
                .offset(x: -CGFloat(currentPage) * width + dragOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
                .gesture(dragGesture(width: width))
                .onTapGesture { onDismiss() }
            }
            .clipped()

            PageDots(count: pages.count, current: currentPage) { index in
                currentPage = clamp(index)
            }
            .opacity(pages.count > 1 ? 1 : 0)
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchPageScroll)) { note in
            let direction = (note.object as? Int) ?? 0
            goTo(currentPage + direction)
        }
        .onChange(of: pages.count) {
            currentPage = clamp(currentPage)
        }
    }

    @ViewBuilder
    private func pageGrid(_ page: [LaunchpadDisplayItem], iconSize: CGFloat, tileHeight: CGFloat) -> some View {
        LaunchpadGridLayout(
            tileHeight: tileHeight
        ) {
            ForEach(page) { item in
                let enlarged = enlargedFolderIDs.contains(item.id)
                tileView(item: item, iconSize: iconSize, tileHeight: tileHeight, enlarged: enlarged)
                    .layoutEnlarged(enlarged)
                    .modifier(TileTrashMenu(
                        item: item,
                        onTrash: onTrash,
                        isEnlarged: enlarged,
                        onEnlarge: onEnlarge,
                        onShrink: onShrink
                    ))
                    .onTapGesture {
                        onLaunch(item)
                    }
                    .draggable(item.id)
                    .dropDestination(for: String.self) { droppedIDs, _ in
                        guard let sourceID = droppedIDs.first, sourceID != item.id else { return false }
                        onDropItem(sourceID, item)
                        return true
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func tileView(item: LaunchpadDisplayItem, iconSize: CGFloat, tileHeight: CGFloat, enlarged: Bool) -> some View {
        if enlarged, case .folder = item.kind {
            EnlargedFolderTileView(item: item, tileHeight: tileHeight)
        } else {
            AppIconView(item: item, iconSize: iconSize, tileHeight: tileHeight)
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold = width * 0.12
                var target = currentPage
                if value.translation.width < -threshold {
                    target += 1
                } else if value.translation.width > threshold {
                    target -= 1
                }
                currentPage = clamp(target)
                dragOffset = 0
            }
    }

    private func goTo(_ page: Int) {
        let target = clamp(page)
        guard target != currentPage else { return }
        currentPage = target
    }

    private func clamp(_ value: Int) -> Int {
        guard pages.count > 0 else { return 0 }
        return min(max(0, value), pages.count - 1)
    }
}

/// Launchpad-style page indicator: a row of dots, the active page enlarged and
/// brightened. Each dot is tappable to jump straight to that page.
struct PageDots: View {
    let count: Int
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white.opacity(0.95) : Color.white.opacity(0.28))
                    .frame(width: 9, height: 9)
                    .scaleEffect(index == current ? 1.25 : 1.0)
                    .contentShape(Circle().inset(by: -6))
                    .onTapGesture { onSelect(index) }
            }
        }
        .padding(.vertical, 8)
        .animation(.easeOut(duration: 0.2), value: current)
    }
}

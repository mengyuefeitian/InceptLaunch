import SwiftUI

struct LaunchpadGridView: View {
    let pages: [[LaunchpadDisplayItem]]
    let onLaunch: (LaunchpadDisplayItem) -> Void
    let onDropItem: (String, LaunchpadDisplayItem) -> Void
    let onTrash: (LaunchpadDisplayItem) -> Void

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0

    private let columns = Array(repeating: GridItem(.fixed(132), spacing: 36), count: 7)

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { geo in
                let width = geo.size.width
                // Size tiles so the busiest page always fits vertically: five
                // full rows at the 150pt design height (886pt with spacing)
                // overflow shorter screens, which used to clip the bottom
                // row's labels. Shrink tiles proportionally when needed.
                let rowCount = min(5, max(1, pages.map { ($0.count + 6) / 7 }.max() ?? 1))
                let tileHeight = min(150, max(96, (geo.size.height - CGFloat(rowCount - 1) * 34) / CGFloat(rowCount)))
                let iconSize = 104 * (tileHeight / 150)
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageGrid(pages[index], iconSize: iconSize, tileHeight: tileHeight)
                            .frame(width: width, height: geo.size.height, alignment: .top)
                    }
                }
                .offset(x: -CGFloat(currentPage) * width + dragOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
                .gesture(dragGesture(width: width))
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
        LazyVGrid(columns: columns, spacing: 34) {
            ForEach(page) { item in
                AppIconView(item: item, iconSize: iconSize, tileHeight: tileHeight)
                    // Long-press must be the innermost gesture or the tap
                    // gesture swallows every press before it can complete.
                    .modifier(TileTrashMenu(item: item, onTrash: onTrash))
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

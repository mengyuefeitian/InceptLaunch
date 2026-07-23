import SwiftUI
import Combine

/// A folder tile enlarged to 2×2 grid cells, showing a 3×3 icon grid inside.
/// If the folder has more than 9 apps, a horizontal carousel lets the user
/// page through them via drag, scroll wheel, arrow buttons, or auto-advance.
struct EnlargedFolderTileView: View {
    let item: LaunchpadDisplayItem
    var tileWidth: CGFloat = GridMetrics.tileWidth
    var tileHeight: CGFloat = GridMetrics.tileHeight
    var columnSpacing: CGFloat = GridMetrics.columnSpacing
    var rowSpacing: CGFloat = GridMetrics.rowSpacing
    var scrollModel: OverlayScrollModel?

    @State private var carouselPage = 0
    @State private var autoAdvanceTimer: Timer?

    private var enlargedWidth: CGFloat { tileWidth * 2 + columnSpacing }
    private var enlargedHeight: CGFloat { tileHeight * 2 + rowSpacing }

    private var members: [AppRecord] { item.members }
    private var pageCount: Int { max(1, (members.count + 8) / 9) }

    /// Icon size for the 3×3 internal grid.
    private var iconSize: CGFloat {
        let available = enlargedWidth - 32 /* horizontal padding */ - 24 /* grid spacing */
        return min(68, max(48, available / 3))
    }

    /// Height reserved for the icon grid area (leaves room for dots + label).
    private var iconAreaHeight: CGFloat {
        // 3 rows × iconSize + 2 gaps × 12pt spacing + top/bottom padding
        3 * iconSize + 2 * 12 + 16
    }

    var body: some View {
        VStack(spacing: 8) {
            // Icon area with explicit height — leaves breathing room below.
            ZStack {
                if pageCount > 1 {
                    carouselContent
                } else {
                    iconGrid(members: Array(members.prefix(9)))
                }
            }
            .frame(width: enlargedWidth - 8, height: iconAreaHeight)
            .clipped()

            // Label — centered below icon area with consistent spacing.
            Text(item.title)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
        }
        .frame(width: enlargedWidth, height: enlargedHeight)
        .liquidGlass(cornerRadius: 28, fallbackOpacity: 0.14)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            scrollModel?.isOverEnlargedFolder = (phase != .ended)
        }
        .onAppear { startAutoAdvance() }
        .onDisappear { stopAutoAdvance() }
    }

    // MARK: - Auto-advance timer

    private func startAutoAdvance() {
        guard pageCount > 1 else { return }
        stopAutoAdvance()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    carouselPage = (carouselPage + 1) % pageCount
                }
            }
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }

    private func resetAutoAdvance() {
        stopAutoAdvance()
        startAutoAdvance()
    }

    // MARK: - Carousel (> 9 members)

    private var carouselContent: some View {
        VStack(spacing: 6) {
            // Swipeable pages with scroll-wheel support
            ZStack {
                ForEach(0..<pageCount, id: \.self) { page in
                    let start = page * 9
                    let slice = Array(members.dropFirst(start).prefix(9))
                    iconGrid(members: slice)
                        .opacity(page == carouselPage ? 1 : 0)
                }
            }
            .overlay(alignment: .center) {
                // Invisible scroll-wheel handler covering the full icon area
                ScrollWheelHandler { direction in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        let next = carouselPage + direction
                        carouselPage = max(0, min(next, pageCount - 1))
                    }
                    resetAutoAdvance()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onEnded { value in
                        if value.translation.width < -20, carouselPage < pageCount - 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                carouselPage += 1
                            }
                            resetAutoAdvance()
                        } else if value.translation.width > 20, carouselPage > 0 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                carouselPage -= 1
                            }
                            resetAutoAdvance()
                        }
                    }
            )

            // Navigation row: left button · dots · right button
            HStack(spacing: 8) {
                // Left arrow
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        carouselPage = max(0, carouselPage - 1)
                    }
                    resetAutoAdvance()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.bold())
                        .foregroundStyle(carouselPage > 0 ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(carouselPage == 0)

                // Page dots
                HStack(spacing: 5) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Circle()
                            .fill(i == carouselPage ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }

                // Right arrow
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        carouselPage = min(pageCount - 1, carouselPage + 1)
                    }
                    resetAutoAdvance()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(carouselPage < pageCount - 1 ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(carouselPage == pageCount - 1)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 3×3 icon grid

    private func iconGrid(members: [AppRecord]) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        if index < members.count {
                            RealAppIcon(record: members[index])
                                .frame(width: iconSize, height: iconSize)
                        } else {
                            Color.clear.frame(width: iconSize, height: iconSize)
                        }
                    }
                }
            }
        }
    }
}

/// NSViewRepresentable wrapper that captures native scroll-wheel events
/// and forwards them as integer direction values (+1 = down/right, −1 = up/left).
struct ScrollWheelHandler: NSViewRepresentable {
    let onScroll: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelCapturingView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollWheelCapturingView)?.onScroll = onScroll
    }
}

private class ScrollWheelCapturingView: NSView {
    var onScroll: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func scrollWheel(with event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        let deltaX = event.scrollingDeltaX
        let delta = abs(deltaY) >= abs(deltaX) ? deltaY : deltaX
        guard abs(delta) > 0.5 else { return }
        // Negative delta = scrolling down/right → advance page
        let direction = delta < 0 ? 1 : -1
        onScroll?(direction)
    }
}

import SwiftUI

/// A folder tile enlarged to 2×2 grid cells, showing a 3×3 icon grid inside.
/// If the folder has more than 9 apps, a horizontal carousel lets the user
/// page through them.
struct EnlargedFolderTileView: View {
    let item: LaunchpadDisplayItem
    var tileWidth: CGFloat = GridMetrics.tileWidth
    var tileHeight: CGFloat = GridMetrics.tileHeight
    var columnSpacing: CGFloat = GridMetrics.columnSpacing
    var rowSpacing: CGFloat = GridMetrics.rowSpacing

    @State private var carouselPage = 0

    private var enlargedWidth: CGFloat { tileWidth * 2 + columnSpacing }
    private var enlargedHeight: CGFloat { tileHeight * 2 + rowSpacing }

    private var members: [AppRecord] { item.members }
    private var pageCount: Int { max(1, (members.count + 8) / 9) }

    /// Icon size for the 3×3 internal grid.  Sized to fill the 2×2 tile
    /// without overflowing (the old 48 pt icons left too much blank space).
    private var iconSize: CGFloat {
        let available = enlargedWidth - 32 /* horizontal padding */ - 24 /* grid spacing */
        return min(68, max(48, available / 3))
    }

    var body: some View {
        VStack(spacing: 6) {
            // Icon area — clipped so icons never bleed past the glass border.
            ZStack {
                if pageCount > 1 {
                    carouselContent
                } else {
                    iconGrid(members: Array(members.prefix(9)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Label — always visible below the icon area with breathing room.
            Text(item.title)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
        .frame(width: enlargedWidth, height: enlargedHeight)
        .liquidGlass(cornerRadius: 28, fallbackOpacity: 0.14)
        .contentShape(Rectangle())
    }

    // MARK: - Carousel (> 9 members)

    private var carouselContent: some View {
        VStack(spacing: 4) {
            // Swipeable pages
            ZStack {
                ForEach(0..<pageCount, id: \.self) { page in
                    let start = page * 9
                    let slice = Array(members.dropFirst(start).prefix(9))
                    iconGrid(members: slice)
                        .opacity(page == carouselPage ? 1 : 0)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onEnded { value in
                        if value.translation.width < -20, carouselPage < pageCount - 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                carouselPage += 1
                            }
                        } else if value.translation.width > 20, carouselPage > 0 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                carouselPage -= 1
                            }
                        }
                    }
            )

            // Page dots
            HStack(spacing: 5) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == carouselPage ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
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

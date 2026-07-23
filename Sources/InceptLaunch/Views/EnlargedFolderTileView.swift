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

    var body: some View {
        VStack(spacing: 8) {
            if pageCount > 1 {
                carouselContent
            } else {
                iconGrid(members: Array(members.prefix(9)))
            }
            Text(item.title)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(.white)
        }
        .frame(width: enlargedWidth, height: enlargedHeight)
        .liquidGlass(cornerRadius: 28, fallbackOpacity: 0.14)
        .contentShape(Rectangle())
    }

    private var carouselContent: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let pageWidth = geo.size.width
                HStack(spacing: 0) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        let start = page * 9
                        let slice = Array(members.dropFirst(start).prefix(9))
                        iconGrid(members: slice)
                            .frame(width: pageWidth)
                    }
                }
                .offset(x: -CGFloat(carouselPage) * pageWidth)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: carouselPage)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            if value.translation.width < -20, carouselPage < pageCount - 1 {
                                carouselPage += 1
                            } else if value.translation.width > 20, carouselPage > 0 {
                                carouselPage -= 1
                            }
                        }
                )
            }

            // Page dots for the carousel
            HStack(spacing: 5) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == carouselPage ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(12)
    }

    private func iconGrid(members: [AppRecord]) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        if index < members.count {
                            RealAppIcon(record: members[index])
                                .frame(width: 48, height: 48)
                        } else {
                            Color.clear.frame(width: 48, height: 48)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}

import SwiftUI

/// Search results rendered as a full-size, vertically scrollable grid.
struct SearchResultsView: View {
    let results: [LaunchpadDisplayItem]
    let onLaunch: (LaunchpadDisplayItem) -> Void
    let onTrash: (LaunchpadDisplayItem) -> Void
    let onHide: (LaunchpadDisplayItem) -> Void
    let onDismiss: () -> Void
    var animate: Bool = true

    private let columns = Array(
        repeating: GridItem(.fixed(GridMetrics.tileWidth), spacing: GridMetrics.columnSpacing),
        count: GridMetrics.columns
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: GridMetrics.rowSpacing) {
                ForEach(results) { item in
                    AppIconView(
                        item: item,
                        iconSize: GridMetrics.iconSize,
                        tileHeight: GridMetrics.tileHeight
                    )
                    .modifier(TileTrashMenu(
                        item: item,
                        onTrash: onTrash,
                        onHide: onHide
                    ))
                    .onTapGesture { onLaunch(item) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onDismiss() })
        .animation(animate ? .easeInOut(duration: 0.25) : nil, value: results.count)
    }
}

import SwiftUI

/// Search results rendered as a full-size, vertically scrollable grid.
///
/// Unlike the paginated launchpad grid, search can return far more apps than
/// fit on one screen, so results keep their full design tile size and scroll
/// vertically instead of shrinking to fit. Column count and tile metrics match
/// the main grid so results line up visually with the apps behind them.
struct SearchResultsView: View {
    let results: [LaunchpadDisplayItem]
    let onLaunch: (LaunchpadDisplayItem) -> Void
    let onTrash: (LaunchpadDisplayItem) -> Void
    let onDismiss: () -> Void

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
                    .modifier(TileTrashMenu(item: item, onTrash: onTrash))
                    .onTapGesture { onLaunch(item) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        // Tapping empty space (around/below the results) dismisses the overlay,
        // just like clicking the backdrop on the plain grid. The full-frame hit
        // shape makes the blank area inside the scroll view respond to taps;
        // each tile's own tap gesture still wins for hits on an app.
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}

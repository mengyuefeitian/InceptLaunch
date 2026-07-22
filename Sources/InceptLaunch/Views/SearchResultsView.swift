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
        // just like clicking the backdrop on the plain grid. A simultaneous
        // gesture is used so the dismiss fires on the FIRST tap even while the
        // search field holds focus — an exclusive tap would be absorbed by the
        // field's defocus handling, forcing the user to tap twice. Firing on a
        // tile tap is harmless because launching an app dismisses anyway.
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { onDismiss() })
    }
}

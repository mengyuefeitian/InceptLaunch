import SwiftUI

struct LaunchpadGridView: View {
    let pages: [[LaunchpadDisplayItem]]
    let onLaunch: (LaunchpadDisplayItem) -> Void

    private let columns = Array(repeating: GridItem(.fixed(112), spacing: 18), count: 7)

    var body: some View {
        TabView {
            ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(page) { item in
                        AppIconView(item: item)
                            .onTapGesture {
                                onLaunch(item)
                            }
                    }
                }
                .padding(40)
            }
        }
        .tabViewStyle(.automatic)
    }
}

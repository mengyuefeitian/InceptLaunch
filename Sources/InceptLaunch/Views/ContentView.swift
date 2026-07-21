import SwiftUI

struct ContentView: View {
    @State private var viewModel = LaunchpadViewModel()

    var body: some View {
        VStack(spacing: 28) {
            SearchFieldView(text: $viewModel.searchText)
            LaunchpadGridView(pages: viewModel.visiblePages) { item in
                if case .app(let record) = item.kind {
                    _ = AppLauncher().launch(record)
                }
            }
        }
        .padding(32)
        .frame(minWidth: 900, minHeight: 640)
        .background(.ultraThinMaterial)
        .task {
            viewModel.bootstrapScan()
        }
    }
}

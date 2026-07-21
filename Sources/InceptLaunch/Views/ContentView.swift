import SwiftUI

struct ContentView: View {
    @State private var viewModel = LaunchpadViewModel()

    var body: some View {
        ZStack {
            // Dark blurred backdrop covering the whole screen.
            Rectangle()
                .fill(.black.opacity(0.55))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                // Clicking empty space dismisses, like Launchpad.
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 32) {
                SearchFieldView(text: $viewModel.searchText)
                    .padding(.top, 60)
                LaunchpadGridView(pages: viewModel.visiblePages) { item in
                    handleTap(item)
                }
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onExitCommand {
            dismiss()
        }
        .task {
            viewModel.bootstrapScan()
        }
    }

    private func handleTap(_ item: LaunchpadDisplayItem) {
        if case .app(let record) = item.kind {
            _ = AppLauncher().launch(record)
            dismiss()
        }
    }

    private func dismiss() {
        NotificationCenter.default.post(name: .inceptLaunchDismiss, object: nil)
    }
}

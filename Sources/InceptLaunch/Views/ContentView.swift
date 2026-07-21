import SwiftUI

struct ContentView: View {
    @State private var viewModel = LaunchpadViewModel()
    @State private var openFolder: LaunchpadDisplayItem?

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
                LaunchpadGridView(
                    pages: viewModel.visiblePages,
                    onLaunch: { item in handleTap(item) },
                    onDropItem: { sourceID, target in
                        viewModel.handleDrop(sourceID: sourceID, onto: target)
                    }
                )
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let folder = openFolder {
                FolderPopupView(
                    item: folder,
                    onLaunch: { record in
                        _ = AppLauncher().launch(record)
                        openFolder = nil
                        dismiss()
                    },
                    onRename: { newName in
                        viewModel.renameFolder(id: folder.id, name: newName)
                        openFolder?.title = newName
                    },
                    onClose: { openFolder = nil }
                )
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: openFolder?.id)
        .onExitCommand {
            if openFolder != nil {
                openFolder = nil
            } else {
                dismiss()
            }
        }
        .task {
            viewModel.bootstrapScan()
        }
    }

    private func handleTap(_ item: LaunchpadDisplayItem) {
        switch item.kind {
        case .app(let record):
            _ = AppLauncher().launch(record)
            dismiss()
        case .folder:
            openFolder = item
        }
    }

    private func dismiss() {
        NotificationCenter.default.post(name: .inceptLaunchDismiss, object: nil)
    }
}

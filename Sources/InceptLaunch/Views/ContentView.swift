import SwiftUI

struct ContentView: View {
    let scrollModel: OverlayScrollModel
    @State private var viewModel = LaunchpadViewModel()
    @State private var openFolder: LaunchpadDisplayItem?
    @FocusState private var searchFocused: Bool

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                SearchFieldView(text: $viewModel.searchText, focused: $searchFocused)
                    .padding(.top, 60)
                Spacer(minLength: 0)
                if isSearching {
                    SearchResultsView(
                        results: viewModel.visiblePages.first ?? [],
                        onLaunch: { item in handleTap(item) },
                        onTrash: { item in
                            Task { await viewModel.moveToTrash(item.id) }
                        },
                        onDismiss: { dismiss() }
                    )
                } else {
                    LaunchpadGridView(
                        pages: viewModel.visiblePages,
                        rows: viewModel.gridRows,
                        onLaunch: { item in handleTap(item) },
                        onDropItem: { sourceID, target in
                            viewModel.handleDrop(sourceID: sourceID, onto: target)
                        },
                        onTrash: { item in
                            Task { await viewModel.moveToTrash(item.id) }
                        }
                    )
                }
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
                    onTrash: { record in
                        Task { await viewModel.moveToTrash(record.id) }
                        openFolder?.members.removeAll { $0.id == record.id }
                        if openFolder?.members.isEmpty == true {
                            openFolder = nil
                        }
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
        .onAppear {
            // The window becomes key a beat after the hosting view appears;
            // defer the focus request briefly so it is not dropped.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
            syncScrollHijack()
        }
        .onChange(of: viewModel.searchText) { syncScrollHijack() }
        .onChange(of: openFolder?.id) { syncScrollHijack() }
    }

    /// Tell the global scroll monitor whether to flip pages or let scrolling
    /// pass through to the active ScrollView (search results / folder popup).
    private func syncScrollHijack() {
        scrollModel.update(isSearching: isSearching, isFolderOpen: openFolder != nil)
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

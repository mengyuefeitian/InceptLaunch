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
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    dismiss()
                })
                .contextMenu {
                    Button {
                        viewModel.tidyGrid()
                    } label: {
                        Label("整理桌面", systemImage: "square.grid.3x3.fill")
                    }
                }

            VStack(spacing: 0) {
                SearchFieldView(text: $viewModel.searchText, focused: $searchFocused)
                    .padding(.top, 60)
                    .padding(.bottom, 32)

                // The grid area below the search field: clicking empty space
                // here must dismiss on the FIRST tap even while the TextField
                // holds focus. .simultaneousGesture on the view that actually
                // receives the hit (not the backdrop behind it) fires during
                // AppKit's defocus handling, unlike .onTapGesture.
                Group {
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
                            enlargedFolderIDs: viewModel.enlargedFolderIDs,
                            onLaunch: { item in handleTap(item) },
                            onDropItem: { sourceID, target in
                                viewModel.handleDrop(sourceID: sourceID, onto: target)
                            },
                            onTrash: { item in
                                Task { await viewModel.moveToTrash(item.id) }
                            },
                            onEnlarge: { item in
                                viewModel.enlargeFolder(id: item.id)
                            },
                            onShrink: { item in
                                viewModel.shrinkFolder(id: item.id)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    dismiss()
                })
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

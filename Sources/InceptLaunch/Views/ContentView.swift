import SwiftUI

struct ContentView: View {
    let scrollModel: OverlayScrollModel
    @Bindable var viewModel: LaunchpadViewModel
    @FocusState private var searchFocused: Bool

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.55))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
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
                            },
                            onDismiss: { dismiss() }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let folder = viewModel.openFolder {
                FolderPopupView(
                    item: folder,
                    onLaunch: { record in
                        _ = AppLauncher().launch(record)
                        viewModel.openFolder = nil
                        dismiss()
                    },
                    onRename: { newName in
                        viewModel.renameFolder(id: folder.id, name: newName)
                        viewModel.openFolder?.title = newName
                    },
                    onTrash: { record in
                        Task { await viewModel.moveToTrash(record.id) }
                        viewModel.openFolder?.members.removeAll { $0.id == record.id }
                        if viewModel.openFolder?.members.isEmpty == true {
                            viewModel.openFolder = nil
                        }
                    },
                    onClose: { viewModel.openFolder = nil }
                )
                .zIndex(1)
            }
        }
        .coordinateSpace(name: "overlay")
        .onPreferenceChange(TileFramePreferenceKey.self) { frames in
            viewModel.tileFrames = frames
            if !frames.isEmpty {
                viewModel.tileFramesReady = true
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.openFolder?.id)
        .onExitCommand {
            if viewModel.openFolder != nil {
                viewModel.openFolder = nil
            } else {
                dismiss()
            }
        }
        .task {
            viewModel.bootstrapScan()
        }
        .onAppear {
            syncScrollHijack()
            // Auto-focus the search field so IME composition works from the
            // first keystroke. The click monitor handles empty-space clicks
            // correctly even when the field is focused.
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchFocusSearch)) { _ in
            searchFocused = true
        }
        .onChange(of: viewModel.searchText) { syncScrollHijack() }
        .onChange(of: viewModel.openFolder?.id) { syncScrollHijack() }
    }

    // MARK: - Helpers

    private func syncScrollHijack() {
        scrollModel.update(isSearching: isSearching, isFolderOpen: viewModel.openFolder != nil)
    }

    private func handleTap(_ item: LaunchpadDisplayItem) {
        switch item.kind {
        case .app(let record):
            _ = AppLauncher().launch(record)
            dismiss()
        case .folder:
            viewModel.openFolder = item
        }
    }

    private func dismiss() {
        NotificationCenter.default.post(name: .inceptLaunchDismiss, object: nil)
    }
}

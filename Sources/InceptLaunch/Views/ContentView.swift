import SwiftUI

struct ContentView: View {
    let scrollModel: OverlayScrollModel
    @Bindable var viewModel: LaunchpadViewModel
    let preferences: UserPreferences
    @FocusState private var searchFocused: Bool

    /// Index into preferences.backgroundImages for carousel rotation.
    @State private var backgroundIndex = 0

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Effective animation flag: false when reduceMotion is on.
    private var animEnabled: Bool { !preferences.reduceMotion }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

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
                            onHide: { item in
                                viewModel.hideApp(id: item.id)
                            },
                            onDismiss: { dismiss() },
                            animate: animEnabled && preferences.animateSearch
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
                            onHide: { item in
                                viewModel.hideApp(id: item.id)
                            },
                            onEnlarge: { item in
                                viewModel.enlargeFolder(id: item.id)
                            },
                            onShrink: { item in
                                viewModel.shrinkFolder(id: item.id)
                            },
                            onDismiss: { dismiss() },
                            animatePageFlip: animEnabled && preferences.animatePageFlip,
                            animateIcons: animEnabled && preferences.animateIcons,
                            animateFolder: animEnabled && preferences.animateFolder,
                            animateDrag: animEnabled && preferences.animateDrag,
                            onPageChange: { newPage in
                                if preferences.backgroundMode == .uploaded && preferences.autoCarousel {
                                    advanceBackground()
                                }
                            },
                            editMode: viewModel.editMode,
                            editDragID: viewModel.editDragID,
                            editDragTranslation: viewModel.editDragTranslation,
                            onEnterEditMode: {
                                viewModel.editMode.toggle()
                            },
                            onMoveApp: { sourceID, targetPage, targetIndex in
                                viewModel.moveAppInGrid(sourceID: sourceID, targetPage: targetPage, targetIndex: targetIndex)
                            },
                            tileFrames: viewModel.tileFrames
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1)
            .contextMenu {
                Button {
                    viewModel.tidyGrid()
                } label: {
                    Label(Localizer.t("menu.tidyGrid"), systemImage: "square.grid.3x3.fill")
                }
            }
            // Tap on empty space dismisses — handled by the grid/search views themselves
            // and the overlay click monitor in OverlayWindowController.

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
                    onClose: { viewModel.openFolder = nil },
                    animate: animEnabled && preferences.animateFolder,
                    editMode: viewModel.editMode,
                    editDragID: viewModel.editDragID,
                    editDragTranslation: viewModel.editDragTranslation,
                    onEnterEditMode: {
                        viewModel.editMode.toggle()
                    },
                    onDragOut: { appID in
                        viewModel.removeAppFromFolder(appID: appID)
                    }
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
        .animation(
            (animEnabled && preferences.animateFolder)
                ? .spring(response: 0.3, dampingFraction: 0.85)
                : nil,
            value: viewModel.openFolder?.id
        )
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
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchFocusSearch)) { _ in
            searchFocused = true
        }
        .onChange(of: viewModel.searchText) { syncScrollHijack() }
        .onChange(of: viewModel.openFolder?.id) { syncScrollHijack() }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchEditDragChanged)) { note in
            if let update = note.object as? EditDragUpdate {
                viewModel.editDragID = update.id
                viewModel.editDragTranslation = update.translation
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchEditDragEnded)) { _ in
            viewModel.editDragID = nil
            viewModel.editDragTranslation = .zero
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        switch preferences.backgroundMode {
        case .desktop:
            if let desktopImage = DesktopWallpaperCapture.currentImage {
                ZStack {
                    Image(nsImage: desktopImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    Rectangle()
                        .fill(.black.opacity(preferences.backgroundBlur))
                }
            } else {
                Rectangle()
                    .fill(.black.opacity(preferences.backgroundBlur))
                    .background(.ultraThinMaterial)
            }
        case .uploaded:
            if let path = currentBackgroundPath,
               let nsImage = NSImage(contentsOfFile: path) {
                ZStack {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    Rectangle()
                        .fill(.black.opacity(preferences.backgroundBlur * 0.5))
                }
                .transition(.opacity)
            } else {
                Rectangle()
                    .fill(.black.opacity(preferences.backgroundBlur))
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var currentBackgroundPath: String? {
        guard !preferences.backgroundImages.isEmpty else { return nil }
        let idx = backgroundIndex % preferences.backgroundImages.count
        return preferences.backgroundImages[idx]
    }

    private func advanceBackground() {
        guard preferences.backgroundImages.count > 1 else { return }
        backgroundIndex = (backgroundIndex + 1) % preferences.backgroundImages.count
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

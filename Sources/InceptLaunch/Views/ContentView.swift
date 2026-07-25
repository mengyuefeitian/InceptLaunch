import AppKit
import SwiftUI

struct ContentView: View {
    let scrollModel: OverlayScrollModel
    @Bindable var viewModel: LaunchpadViewModel
    let preferences: UserPreferences

    @State private var backgroundIndex = 0

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var animEnabled: Bool { !preferences.reduceMotion }

    /// Must match AppKit search chrome so results/grid never paint under it.
    private var searchChromeHeight: CGFloat { OverlaySearchChrome.chromeHeight }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { handleBlankTap() }

                // Hard split: top chrome reserved, bottom content clipped.
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: searchChromeHeight)
                        .allowsHitTesting(false)

                    contentBody
                        .frame(
                            width: geo.size.width,
                            height: max(0, geo.size.height - searchChromeHeight)
                        )
                        .clipped()
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)

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
                            viewModel.editMode = true
                        },
                        onCancelEditMode: {
                            viewModel.editMode = false
                        },
                        onDragOutBegan: { appID, point in
                            viewModel.beginFloatingDragOut(appID: appID, at: point)
                            NotificationCenter.default.post(
                                name: .inceptLaunchStartFloatingDrag,
                                object: appID
                            )
                        },
                        onDragOutEnded: { _, _ in },
                        onReorder: { appID, newIndex in
                            if case .folder(let f) = folder.kind {
                                if animEnabled && preferences.animateDrag {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.liveReorderInFolder(folderID: f.id, appID: appID, toIndex: newIndex)
                                    }
                                } else {
                                    viewModel.liveReorderInFolder(folderID: f.id, appID: appID, toIndex: newIndex)
                                }
                            }
                        },
                        onReorderEnded: {
                            viewModel.persistCurrentLayout()
                        }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .zIndex(2)
                }

                if let dragItem = viewModel.gridDragItem {
                    AppIconView(
                        item: dragItem,
                        iconSize: GridMetrics.iconSize,
                        tileHeight: GridMetrics.tileHeight
                    )
                    .scaleEffect(1.15)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                    .opacity(0.9)
                    .position(viewModel.gridDragLocation)
                    .allowsHitTesting(false)
                    .zIndex(3)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
            handleBlankTap()
        }
        .task {
            viewModel.bootstrapScan()
        }
        .onAppear {
            syncScrollHijack()
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
            if viewModel.floatingDragApp == nil {
                viewModel.editDragID = nil
                viewModel.editDragTranslation = .zero
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchGridDragMoved)) { note in
            if let update = note.object as? GridDragLocationUpdate {
                if viewModel.gridDragItem == nil {
                    viewModel.gridDragItem = viewModel.visiblePages
                        .flatMap { $0 }
                        .first(where: { $0.id == update.id })
                }
                viewModel.gridDragLocation = update.location
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchGridDragEnded)) { _ in
            viewModel.endLiveReorder()
            viewModel.gridDragItem = nil
            viewModel.gridDragLocation = .zero
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchEditModeCancelled)) { _ in
            viewModel.editMode = false
        }
    }

    @ViewBuilder
    private var contentBody: some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                    viewModel.currentPage = newPage
                    if preferences.backgroundMode == .uploaded && preferences.autoCarousel {
                        advanceBackground()
                    }
                },
                editMode: viewModel.editMode,
                editDragID: viewModel.editDragID,
                editDragTranslation: viewModel.editDragTranslation,
                onEnterEditMode: {
                    viewModel.editMode = true
                },
                onCancelEditMode: {
                    viewModel.editMode = false
                },
                onMoveApp: { sourceID, targetPage, targetIndex in
                    viewModel.moveAppInGrid(sourceID: sourceID, targetPage: targetPage, targetIndex: targetIndex)
                },
                onResolveDrop: { sourceID, point, translation, page, localIndex in
                    viewModel.resolveDrop(
                        sourceID: sourceID,
                        at: point,
                        translation: translation,
                        page: page,
                        sourceIndex: localIndex
                    )
                },
                onLiveReorder: { draggedID, toIndex, page in
                    viewModel.beginLiveReorder(draggedID: draggedID, page: page)
                    if animEnabled && preferences.animateDrag {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.liveReorder(draggedID: draggedID, toIndex: toIndex, page: page)
                        }
                    } else {
                        viewModel.liveReorder(draggedID: draggedID, toIndex: toIndex, page: page)
                    }
                },
                tileFrames: viewModel.tileFrames
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu {
                Button {
                    viewModel.tidyGrid()
                } label: {
                    Label(Localizer.t("menu.tidyGrid"), systemImage: "square.grid.3x3.fill")
                }
            }
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

    private func handleBlankTap() {
        // Order: jiggle → folder → exit fullscreen (including while searching).
        if viewModel.editMode {
            viewModel.editMode = false
        } else if viewModel.openFolder != nil {
            DiagLog.write("handleBlankTap closing folder")
            viewModel.openFolder = nil
        } else if viewModel.floatingDragApp == nil {
            dismiss()
        }
    }

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

extension Notification.Name {
    static let inceptLaunchStartFloatingDrag = Notification.Name("inceptLaunchStartFloatingDrag")
    static let inceptLaunchClearSearch = Notification.Name("inceptLaunchClearSearch")
}

import SwiftUI

struct ContentView: View {
    let scrollModel: OverlayScrollModel
    @State private var viewModel = LaunchpadViewModel()
    @State private var openFolder: LaunchpadDisplayItem?
    @State private var keyMonitor: Any?
    @State private var defocusMonitor: Any?
    @State private var dismissMonitor: Any?
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
        .coordinateSpace(name: "overlay")
        .onPreferenceChange(TileFramePreferenceKey.self) { frames in
            viewModel.tileFrames = frames
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
            installMonitors()
            syncScrollHijack()
            // Auto-focus the search field so IME composition works from the
            // first keystroke. The dismissMonitor/defocusMonitor handle empty-
            // space clicks correctly even when the field is focused.
            searchFocused = true
        }
        .onDisappear {
            removeMonitors()
        }
        .onChange(of: viewModel.searchText) { syncScrollHijack() }
        .onChange(of: openFolder?.id) { syncScrollHijack() }
    }

    // MARK: - Event Monitors

    /// Three monitors handle overlay dismissal and search-field focus:
    ///
    /// 1. **keyDown monitor**: safety net — focuses the search field if it
    ///    somehow lost focus and the user starts typing.
    ///
    /// 2. **defocusMonitor**: when the search field IS focused and the user
    ///    clicks outside it, resign focus. If the click is on empty space
    ///    (not on any tile), also dismiss the overlay. If the click is on a
    ///    tile, just defocus and let the tile's gesture fire.
    ///
    /// 3. **dismissMonitor**: when the search field is NOT focused, check
    ///    whether the click landed on a tile (pass through) or empty space
    ///    (dismiss and consume).
    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            guard let chars = event.characters,
                  let first = chars.unicodeScalars.first,
                  first.value >= 32, first.value != 127 else {
                return event
            }
            if !searchFocused {
                searchFocused = true
            }
            return event
        }

        // When the search field IS focused, clicking outside defocuses.
        // If the click is on empty space (not on a tile), also dismiss.
        // If the click is on a tile, just defocus so the tile's gesture fires.
        defocusMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [self] event in
            guard let window = event.window,
                  let fieldEditor = window.firstResponder as? NSTextView,
                  fieldEditor.isFieldEditor else {
                return event
            }
            if let fieldView = fieldEditor.superview {
                let frameInWindow = fieldView.convert(fieldView.bounds, to: nil)
                if frameInWindow.contains(event.locationInWindow) {
                    return event  // Click inside the field — let it through
                }
            }
            // Click is outside the search field — defocus.
            window.makeFirstResponder(nil)

            // Check if the click is on a tile (using content-view coordinates).
            if let contentView = window.contentView {
                let windowHeight = contentView.bounds.height
                let mouseLoc = event.locationInWindow
                let contentViewPoint = CGPoint(x: mouseLoc.x, y: windowHeight - mouseLoc.y)
                let onTile = viewModel.tileFrames.contains { $0.contains(contentViewPoint) }
                if onTile {
                    return event  // On a tile — let the tile's gesture fire
                }
            }
            // Empty space — dismiss and consume.
            NotificationCenter.default.post(name: .inceptLaunchDismiss, object: nil)
            return nil
        }

        // When the search field is NOT focused, check if the click is on a tile
        // or empty space. Tiles pass through; empty space dismisses.
        dismissMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [self] event in
            // If the search field is focused, let the defocusMonitor handle it.
            if let window = event.window,
               let fieldEditor = window.firstResponder as? NSTextView,
               fieldEditor.isFieldEditor {
                return event
            }
            // Convert mouse location from AppKit coords (origin bottom-left)
            // to content-view coords (origin top-left) to match tile frames.
            guard let window = event.window,
                  let contentView = window.contentView else {
                return event
            }
            let windowHeight = contentView.bounds.height
            let mouseLoc = event.locationInWindow
            let contentViewPoint = CGPoint(
                x: mouseLoc.x,
                y: windowHeight - mouseLoc.y
            )
            // Check if the click is inside any tracked tile frame.
            let onTile = viewModel.tileFrames.contains { $0.contains(contentViewPoint) }
            if onTile {
                return event  // Let the tile's gesture handle it
            }
            // Empty space click — dismiss and consume the event.
            NotificationCenter.default.post(name: .inceptLaunchDismiss, object: nil)
            return nil
        }
    }

    private func removeMonitors() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let m = defocusMonitor { NSEvent.removeMonitor(m); defocusMonitor = nil }
        if let m = dismissMonitor { NSEvent.removeMonitor(m); dismissMonitor = nil }
    }

    // MARK: - Helpers

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

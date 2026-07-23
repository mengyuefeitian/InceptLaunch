import SwiftUI

struct ContentView: View {
    let scrollModel: OverlayScrollModel
    @State private var viewModel = LaunchpadViewModel()
    @State private var openFolder: LaunchpadDisplayItem?
    @State private var keyMonitor: Any?
    @State private var defocusMonitor: Any?
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
        }
        .onDisappear {
            removeMonitors()
        }
        .onChange(of: viewModel.searchText) { syncScrollHijack() }
        .onChange(of: openFolder?.id) { syncScrollHijack() }
    }

    // MARK: - Event Monitors

    /// Two monitors solve the single-tap-dismiss problem:
    ///
    /// 1. **keyDown monitor**: focuses the search field when the user types a
    ///    printable character. The field is NOT auto-focused on appear, so
    ///    clicking empty space never triggers AppKit's defocus-eats-the-click.
    ///
    /// 2. **mouseDown monitor**: if the field IS focused (user typed something)
    ///    and they click outside it, resign focus immediately so the subsequent
    ///    .onTapGesture fires on the same click.
    private func installMonitors() {
        // Focus the search field when the user starts typing.
        // We do NOT swallow the event or manually append the character —
        // doing so breaks IME composition (e.g. Pinyin "douyin" became
        // "欧银" because "d" was inserted as raw English before the IME
        // could start composing).  The first keystroke may be lost during
        // the focus transition, but all subsequent keystrokes reach the
        // text field through the normal responder chain and the IME works
        // correctly.
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

        // Resign search field focus on outside click AND dismiss immediately.
        // The AppKit monitor fires before SwiftUI gesture recognition, so
        // relying on the SwiftUI .onTapGesture to also fire on the same click
        // is unreliable (the gesture can be absorbed by the focus change).
        // Posting the dismiss notification directly from the monitor ensures
        // a single click both defocuses the field and closes the overlay.
        defocusMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window,
                  let fieldEditor = window.firstResponder as? NSTextView,
                  fieldEditor.isFieldEditor else {
                return event
            }
            if let fieldView = fieldEditor.superview {
                let frameInWindow = fieldView.convert(fieldView.bounds, to: nil)
                if frameInWindow.contains(event.locationInWindow) {
                    return event
                }
            }
            window.makeFirstResponder(nil)
            NotificationCenter.default.post(name: .inceptLaunchDismiss, object: nil)
            return event
        }
    }

    private func removeMonitors() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let m = defocusMonitor { NSEvent.removeMonitor(m); defocusMonitor = nil }
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

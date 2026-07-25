import SwiftUI

struct LaunchpadGridView: View {
    let pages: [[LaunchpadDisplayItem]]
    let rows: Int
    let enlargedFolderIDs: Set<String>
    let onLaunch: (LaunchpadDisplayItem) -> Void
    let onDropItem: (String, LaunchpadDisplayItem) -> Void
    let onTrash: (LaunchpadDisplayItem) -> Void
    let onHide: (LaunchpadDisplayItem) -> Void
    let onEnlarge: (LaunchpadDisplayItem) -> Void
    let onShrink: (LaunchpadDisplayItem) -> Void
    let onDismiss: () -> Void
    var animatePageFlip: Bool = true
    var animateIcons: Bool = true
    var animateFolder: Bool = true
    var animateDrag: Bool = true
    var onPageChange: ((Int) -> Void)? = nil

    // Edit mode — backed by the ViewModel's @Observable properties.
    var editMode: Bool = false
    var editDragID: String? = nil
    var editDragTranslation: CGSize = .zero
    var onEnterEditMode: (() -> Void)? = nil
    /// Explicit cancel (blank tap while jiggling). Must set editMode=false.
    var onCancelEditMode: (() -> Void)? = nil
    var onMoveApp: ((String, Int, Int) -> Void)? = nil
    /// Unified drop: (sourceID, location, translation, page, sourceLocalIndex).
    var onResolveDrop: ((String, CGPoint, CGSize, Int, Int) -> Void)? = nil
    var onLiveReorder: ((String, Int, Int) -> Void)? = nil
    var tileFrames: [TileFrameInfo] = []

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var dragPageOffset: CGFloat = 0
    @State private var lastEdgePageFlip = Date.distantPast
    @State private var pageWidthCache: CGFloat = 0
    @State private var pageOriginX: CGFloat = 0
    /// True while a tile drag is active (so blank-tap doesn't steal the gesture).
    @State private var isDraggingTile = false

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { geo in
                let width = geo.size.width
                let fitted = (geo.size.height - CGFloat(rows - 1) * GridMetrics.rowSpacing) / CGFloat(rows)
                let tileHeight = min(GridMetrics.tileHeight, max(96, fitted))
                let iconSize = GridMetrics.iconSize * (tileHeight / GridMetrics.tileHeight)
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageGrid(pages[index], iconSize: iconSize, tileHeight: tileHeight, pageWidth: width, pageIndex: index)
                            .frame(width: width, height: geo.size.height, alignment: .center)
                    }
                }
                .offset(x: -CGFloat(currentPage) * width + dragOffset)
                .animation(
                    (editMode || isDraggingTile)
                        ? nil
                        : (animatePageFlip ? .spring(response: 0.35, dampingFraction: 0.85) : nil),
                    value: currentPage
                )
                // Page swipe only when not in edit mode and not mid-tile-drag.
                .gesture((editMode || isDraggingTile) ? nil : dragGesture(width: width))
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode {
                        onCancelEditMode?()
                    } else if !isDraggingTile {
                        onDismiss()
                    }
                }
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear {
                                pageWidthCache = width
                                pageOriginX = g.frame(in: .named("overlay")).minX
                            }
                            .onChange(of: width) { _, w in
                                pageWidthCache = w
                                pageOriginX = g.frame(in: .named("overlay")).minX
                            }
                    }
                )
            }
            .clipped()

            PageDots(count: pages.count, current: currentPage) { index in
                goTo(index)
            }
            .opacity(pages.count > 1 ? 1 : 0)
        }
        .onReceive(NotificationCenter.default.publisher(for: .inceptLaunchPageScroll)) { note in
            let direction = (note.object as? Int) ?? 0
            goTo(currentPage + direction)
        }
        .onChange(of: pages.count) {
            currentPage = clamp(currentPage)
        }
        .onChange(of: editMode) { _, _ in
            dragPageOffset = 0
            lastEdgePageFlip = .distantPast
        }
    }

    @ViewBuilder
    private func pageGrid(_ page: [LaunchpadDisplayItem], iconSize: CGFloat, tileHeight: CGFloat, pageWidth: CGFloat, pageIndex: Int) -> some View {
        LaunchpadGridLayout(
            tileHeight: tileHeight,
            minRows: rows
        ) {
            ForEach(page) { item in
                let idx = page.firstIndex(where: { $0.id == item.id }) ?? 0
                tileCell(item: item, localIndex: idx, iconSize: iconSize, tileHeight: tileHeight, pageWidth: pageWidth, pageIndex: pageIndex)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func tileCell(item: LaunchpadDisplayItem, localIndex: Int, iconSize: CGFloat, tileHeight: CGFloat, pageWidth: CGFloat, pageIndex: Int) -> some View {
        let enlarged = enlargedFolderIDs.contains(item.id)
        let isBeingDragged = editDragID == item.id
        let dragTrans = isBeingDragged ? editDragTranslation : .zero
        let isFolder: Bool = {
            if case .folder = item.kind { return true }
            return false
        }()
        // Folders look larger — keep rotation tiny so they don't "whip" around.
        let tileJiggleAmplitude: Double = {
            var generator = SeededGenerator(seed: UInt64(item.id.hashValue & 0xFFFFFFFF))
            let range: ClosedRange<Double> = isFolder ? 0.2...0.35 : 0.55...0.9
            return Double.random(in: range, using: &generator)
        }()

        // TimelineView drives jiggle; `layoutEnlarged` MUST be on the Layout's
        // direct child (this outer chain). Putting it only *inside* TimelineView
        // made enlarged folders occupy 1 cell while drawing 2×2 → icons stacked
        // on top of the big folder.
        TimelineView(.animation(minimumInterval: 0.05, paused: !editMode || isBeingDragged)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let angle = (editMode && !isBeingDragged)
                ? sin(phase * 22.0) * tileJiggleAmplitude
                : 0.0

            tileView(item: item, iconSize: iconSize, tileHeight: tileHeight, enlarged: enlarged)
                .scaleEffect(isBeingDragged ? 1.1 : 1.0)
                .shadow(color: isBeingDragged ? .black.opacity(0.45) : .clear, radius: 16, y: 8)
                .rotationEffect(.degrees(angle))
                .offset(dragTrans)
                .opacity(isBeingDragged && animateDrag ? 0.0 : (isBeingDragged ? 0.92 : 1.0))
        }
        // zIndex on the Layout child so the dragged tile paints above folders
        // (not under them mid-drag).
        .zIndex(isBeingDragged ? 1000 : 0)
        .layoutEnlarged(enlarged)
        .modifier(TileTrashMenu(
            item: item,
            onTrash: onTrash,
            isEnlarged: enlarged,
            onEnlarge: onEnlarge,
            onShrink: onShrink,
            onHide: onHide,
            editMode: editMode
        ))
        .contentShape(Rectangle())
        .onTapGesture {
            if editMode {
                onCancelEditMode?()
            } else {
                onLaunch(item)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4, maximumDistance: 6)
                .onEnded { _ in
                    onEnterEditMode?()
                }
        )
        .gesture(directDragGesture(item: item, localIndex: localIndex, pageWidth: pageWidth, pageIndex: pageIndex))
        .modifier(TileFramePreferenceModifier(id: item.id, isFolder: isFolder))
    }

    /// Click-drag to reorder (apps + folders) or form folders (apps only, >50%).
    private func directDragGesture(
        item: LaunchpadDisplayItem,
        localIndex: Int,
        pageWidth: CGFloat,
        pageIndex: Int
    ) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("overlay"))
            .onChanged { value in
                isDraggingTile = true
                let translation = CGSize(
                    width: value.translation.width + dragPageOffset,
                    height: value.translation.height
                )
                maybeFlipPageAtEdge(fingerX: value.location.x, pageWidth: pageWidth)

                // Live reorder: compute target index from pointer position.
                if animateDrag, let onLiveReorder {
                    let targetIndex = computeGridTargetIndex(
                        dragID: item.id,
                        location: value.location,
                        page: currentPage
                    )
                    let currentIndex = pages[currentPage].firstIndex(where: { $0.id == item.id }) ?? localIndex
                    if targetIndex != currentIndex {
                        onLiveReorder(item.id, targetIndex, currentPage)
                    }
                }

                NotificationCenter.default.post(
                    name: .inceptLaunchEditDragChanged,
                    object: EditDragUpdate(id: item.id, translation: translation)
                )
                NotificationCenter.default.post(
                    name: .inceptLaunchGridDragMoved,
                    object: GridDragLocationUpdate(id: item.id, location: value.location)
                )
            }
            .onEnded { value in
                defer {
                    isDraggingTile = false
                    dragPageOffset = 0
                    NotificationCenter.default.post(name: .inceptLaunchEditDragEnded, object: nil)
                    NotificationCenter.default.post(name: .inceptLaunchGridDragEnded, object: nil)
                }

                let translation = CGSize(
                    width: value.translation.width + dragPageOffset,
                    height: value.translation.height
                )

                // Unified resolver: >50% app merge, otherwise cell-based insert.
                // Pass source localIndex + translation so insert lands between
                // the intended neighbors (not a wrong row).
                if let onResolveDrop {
                    onResolveDrop(item.id, value.location, translation, currentPage, localIndex)
                    return
                }

                if currentPage != pageIndex || translation != .zero {
                    onMoveApp?(item.id, currentPage, localIndex)
                }
            }
    }

    private func computeGridTargetIndex(dragID: String, location: CGPoint, page: Int) -> Int {
        let pageItems = pages[page]
        let otherFrames = tileFrames
            .filter { frame in
                frame.id != dragID && pageItems.contains(where: { $0.id == frame.id })
            }
            .sorted { a, b in
                let indexA = pageItems.firstIndex(where: { $0.id == a.id }) ?? 0
                let indexB = pageItems.firstIndex(where: { $0.id == b.id }) ?? 0
                return indexA < indexB
            }

        for (rank, info) in otherFrames.enumerated() {
            if location.x < info.frame.midX && location.y < info.frame.maxY {
                return rank
            }
        }
        return pageItems.count - 1
    }

    private func maybeFlipPageAtEdge(fingerX: CGFloat, pageWidth: CGFloat) {
        let width = pageWidth > 0 ? pageWidth : pageWidthCache
        guard width > 0 else { return }
        let localX = fingerX - pageOriginX
        let edgeZone: CGFloat = 56
        let now = Date()
        guard now.timeIntervalSince(lastEdgePageFlip) > 0.55 else { return }

        if localX < edgeZone, currentPage > 0 {
            currentPage -= 1
            dragPageOffset -= width
            lastEdgePageFlip = now
            onPageChange?(currentPage)
        } else if localX > width - edgeZone, currentPage < pages.count - 1 {
            currentPage += 1
            dragPageOffset += width
            lastEdgePageFlip = now
            onPageChange?(currentPage)
        }
    }

    @ViewBuilder
    private func tileView(item: LaunchpadDisplayItem, iconSize: CGFloat, tileHeight: CGFloat, enlarged: Bool) -> some View {
        if enlarged, case .folder = item.kind {
            EnlargedFolderTileView(item: item, tileHeight: tileHeight)
        } else {
            AppIconView(item: item, iconSize: iconSize, tileHeight: tileHeight)
        }
    }

    // MARK: - Normal page drag gesture

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold = width * 0.12
                var target = currentPage
                if value.translation.width < -threshold {
                    target += 1
                } else if value.translation.width > threshold {
                    target -= 1
                }
                let newPage = clamp(target)
                let changed = newPage != currentPage
                currentPage = newPage
                dragOffset = 0
                if changed {
                    onPageChange?(newPage)
                }
            }
    }

    private func goTo(_ page: Int) {
        let target = clamp(page)
        guard target != currentPage else { return }
        currentPage = target
        onPageChange?(target)
    }

    private func clamp(_ value: Int) -> Int {
        guard pages.count > 0 else { return 0 }
        return min(max(0, value), pages.count - 1)
    }

}

// MARK: - Tile Frame Preference Helper

private struct TileFramePreferenceModifier: ViewModifier {
    let id: String
    let isFolder: Bool

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TileFramePreferenceKey.self,
                    value: [TileFrameInfo(id: id, frame: proxy.frame(in: .named("overlay")), isFolder: isFolder)]
                )
            }
        }
    }
}

// MARK: - Edit Drag Notifications

struct EditDragUpdate {
    let id: String
    let translation: CGSize
}

struct GridDragLocationUpdate {
    let id: String
    let location: CGPoint
}

extension Notification.Name {
    static let inceptLaunchEditDragChanged = Notification.Name("inceptLaunchEditDragChanged")
    static let inceptLaunchEditDragEnded = Notification.Name("inceptLaunchEditDragEnded")
    static let inceptLaunchGridDragMoved = Notification.Name("inceptLaunchGridDragMoved")
    static let inceptLaunchGridDragEnded = Notification.Name("inceptLaunchGridDragEnded")
}

/// Launchpad-style page indicator
struct PageDots: View {
    let count: Int
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white.opacity(0.95) : Color.white.opacity(0.28))
                    .frame(width: 9, height: 9)
                    .scaleEffect(index == current ? 1.25 : 1.0)
                    .contentShape(Circle().inset(by: -6))
                    .onTapGesture { onSelect(index) }
            }
        }
        .padding(.vertical, 8)
        .animation(.easeOut(duration: 0.2), value: current)
    }
}

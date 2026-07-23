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
    var onMoveApp: ((String, Int, Int) -> Void)? = nil
    var tileFrames: [CGRect] = []

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var jiggle = false

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
                    animatePageFlip ? .spring(response: 0.35, dampingFraction: 0.85) : nil,
                    value: currentPage
                )
                .gesture(editMode ? nil : dragGesture(width: width))
                .onTapGesture { if !editMode { onDismiss() } }
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
        .onChange(of: editMode) { _, newValue in
            if newValue {
                withAnimation(.linear(duration: 0.15).repeatForever(autoreverses: true)) {
                    jiggle = true
                }
            } else {
                withAnimation(.linear(duration: 0.15)) {
                    jiggle = false
                }
            }
        }
    }

    @ViewBuilder
    private func pageGrid(_ page: [LaunchpadDisplayItem], iconSize: CGFloat, tileHeight: CGFloat, pageWidth: CGFloat, pageIndex: Int) -> some View {
        LaunchpadGridLayout(
            tileHeight: tileHeight,
            minRows: rows
        ) {
            ForEach(page.indices, id: \.self) { idx in
                let item = page[idx]
                tileCell(item: item, localIndex: idx, iconSize: iconSize, tileHeight: tileHeight, pageWidth: pageWidth, pageIndex: pageIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func tileCell(item: LaunchpadDisplayItem, localIndex: Int, iconSize: CGFloat, tileHeight: CGFloat, pageWidth: CGFloat, pageIndex: Int) -> some View {
        let enlarged = enlargedFolderIDs.contains(item.id)
        let isBeingDragged = editMode && editDragID == item.id
        let dragTrans = isBeingDragged ? editDragTranslation : .zero

        tileView(item: item, iconSize: iconSize, tileHeight: tileHeight, enlarged: enlarged)
            .layoutEnlarged(enlarged)
            .opacity(isBeingDragged ? 0.3 : 1.0)
            .rotationEffect(jiggleAngle(isBeingDragged: isBeingDragged))
            .offset(dragTrans)
            .modifier(TileTrashMenu(
                item: item,
                onTrash: onTrash,
                isEnlarged: enlarged,
                onEnlarge: onEnlarge,
                onShrink: onShrink,
                onHide: onHide
            ))
            .contentShape(Rectangle())
            .onTapGesture {
                if editMode {
                    onEnterEditMode?()
                } else {
                    onLaunch(item)
                }
            }
            .onLongPressGesture(minimumDuration: 0.6) {
                if !editMode {
                    onEnterEditMode?()
                }
            }
            .gesture(editMode && !isBeingDragged
                ? editDragGesture(item: item, pageWidth: pageWidth, pageIndex: pageIndex, localIndex: localIndex)
                : nil
            )
            .modifier(DraggableModifier(enabled: !editMode, id: item.id))
            .dropDestination(for: String.self) { droppedIDs, _ in
                guard !editMode else { return false }
                guard let sourceID = droppedIDs.first, sourceID != item.id else { return false }
                onDropItem(sourceID, item)
                return true
            }
            .modifier(TileFramePreferenceModifier())
    }

    private func jiggleAngle(isBeingDragged: Bool) -> Angle {
        guard editMode && !isBeingDragged else { return .degrees(0) }
        return jiggle ? .degrees(1.5) : .degrees(-1.5)
    }

    @ViewBuilder
    private func tileView(item: LaunchpadDisplayItem, iconSize: CGFloat, tileHeight: CGFloat, enlarged: Bool) -> some View {
        if enlarged, case .folder = item.kind {
            EnlargedFolderTileView(item: item, tileHeight: tileHeight)
        } else {
            AppIconView(item: item, iconSize: iconSize, tileHeight: tileHeight)
        }
    }

    // MARK: - Edit mode drag gesture

    private func editDragGesture(item: LaunchpadDisplayItem, pageWidth: CGFloat, pageIndex: Int, localIndex: Int) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                onEnterEditMode?()  // ensure edit mode is on
                // We can't mutate @Observable from here directly, but we can
                // use the callback pattern. Store translation via a notification.
                NotificationCenter.default.post(
                    name: .inceptLaunchEditDragChanged,
                    object: EditDragUpdate(id: item.id, translation: value.translation)
                )

                // Cross-page detection
                let threshold = pageWidth * 0.15
                if value.translation.width < -threshold, currentPage > 0 {
                    let newPage = currentPage - 1
                    currentPage = newPage
                    NotificationCenter.default.post(
                        name: .inceptLaunchEditDragChanged,
                        object: EditDragUpdate(id: item.id, translation: CGSize(
                            width: value.translation.width + pageWidth,
                            height: value.translation.height
                        ))
                    )
                    onPageChange?(newPage)
                    onMoveApp?(item.id, newPage, 0)
                } else if value.translation.width > threshold, currentPage < pages.count - 1 {
                    let newPage = currentPage + 1
                    currentPage = newPage
                    NotificationCenter.default.post(
                        name: .inceptLaunchEditDragChanged,
                        object: EditDragUpdate(id: item.id, translation: CGSize(
                            width: value.translation.width - pageWidth,
                            height: value.translation.height
                        ))
                    )
                    onPageChange?(newPage)
                    onMoveApp?(item.id, newPage, 0)
                }
            }
            .onEnded { value in
                // Find the tile under the drop point
                let frames = tileFrames
                let dropTranslation = value.translation

                // Find the source tile's frame (approximate by finding the tile
                // whose frame is closest to where we expect it)
                var bestFrame: CGRect?
                var bestDist: CGFloat = .greatestFiniteMagnitude
                for frame in frames {
                    let dist = abs(frame.midX - (frame.midX + dropTranslation.width))
                    if dist < bestDist {
                        bestDist = dist
                        bestFrame = frame
                    }
                }

                if let sourceFrame = bestFrame {
                    let dropCenter = CGPoint(
                        x: sourceFrame.midX + dropTranslation.width,
                        y: sourceFrame.midY + dropTranslation.height
                    )

                    for (index, frame) in frames.enumerated() {
                        if frame.contains(dropCenter) {
                            let targetPage = pageForFrameIndex(index)
                            let targetIndex = indexInPage(forFrameIndex: index, page: targetPage)
                            onMoveApp?(item.id, targetPage, targetIndex)
                            break
                        }
                    }
                }

                // Clear drag state
                NotificationCenter.default.post(
                    name: .inceptLaunchEditDragEnded,
                    object: nil
                )
            }
    }

    private func pageForFrameIndex(_ frameIndex: Int) -> Int {
        var cumulative = 0
        for (pageIndex, page) in pages.enumerated() {
            cumulative += page.count
            if frameIndex < cumulative {
                return pageIndex
            }
        }
        return currentPage
    }

    private func indexInPage(forFrameIndex frameIndex: Int, page: Int) -> Int {
        var cumulative = 0
        for pageIndex in 0..<page {
            cumulative += pages[pageIndex].count
        }
        return max(0, frameIndex - cumulative)
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
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TileFramePreferenceKey.self,
                    value: [proxy.frame(in: .named("overlay"))]
                )
            }
        }
    }
}

/// Conditionally applies .draggable — avoids the ternary-with-nil issue.
private struct DraggableModifier: ViewModifier {
    let enabled: Bool
    let id: String

    func body(content: Content) -> some View {
        if enabled {
            content.draggable(id)
        } else {
            content
        }
    }
}

// MARK: - Edit Drag Notifications

struct EditDragUpdate {
    let id: String
    let translation: CGSize
}

extension Notification.Name {
    static let inceptLaunchEditDragChanged = Notification.Name("inceptLaunchEditDragChanged")
    static let inceptLaunchEditDragEnded = Notification.Name("inceptLaunchEditDragEnded")
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

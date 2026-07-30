import AppKit
import SwiftUI

/// A Launchpad-style zoomed folder: a dark frosted panel listing the contained
/// apps in a grid. The title is click-to-edit. Tapping the dimmed backdrop
/// closes it without dismissing the whole Launchpad.
struct FolderPopupView: View {
    let item: LaunchpadDisplayItem
    let onLaunch: (AppRecord) -> Void
    let onRename: (String) -> Void
    let onTrash: (AppRecord) -> Void
    let onClose: () -> Void
    /// Invoked after the close scale/fade finishes so the parent can nil `openFolder`.
    var onCloseAnimationFinished: (() -> Void)? = nil
    /// When this value increases while the popup is visible, play the close animation.
    var closeEpoch: Int = 0
    var animate: Bool = true
    var wallpaperImage: NSImage? = nil
    var backgroundBlur: Double = 0.72

    var iconSizeLevel: UserPreferences.IconSizeLevel = .large

    // Edit mode support
    var editMode: Bool = false
    var editDragID: String? = nil
    var editDragTranslation: CGSize = .zero
    var onEnterEditMode: (() -> Void)? = nil
    var onCancelEditMode: (() -> Void)? = nil
    /// Called mid-drag once the pointer leaves the folder — closes popup and
    /// starts a floating ghost under the cursor.
    var onDragOutBegan: ((String, CGPoint) -> Void)? = nil
    /// Called on drop after drag-out (or local reorder-out).
    var onDragOutEnded: ((String, CGPoint) -> Void)? = nil
    /// Called during drag to reorder an app within the folder.
    var onReorder: ((String, Int) -> Void)? = nil
    /// Called when a folder-interior reorder drag ends (to persist layout).
    var onReorderEnded: (() -> Void)? = nil
    /// Reports panelFrame changes so the AppKit click monitor can tell
    /// outside-panel backdrop clicks (dismiss) from inside-panel clicks
    /// (member tap / reorder / drag-out, which must reach SwiftUI).
    var onPanelFrameChanged: ((CGRect) -> Void)? = nil
    /// Grid tile frame in overlay coordinates (origin top-left) — zoom origin/target.
    var sourceFrame: CGRect = .zero
    /// Full overlay size for computing the panel’s resting center.
    var overlaySize: CGSize = .zero

    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var leftFolder = false
    @State private var memberFrames: [String: CGRect] = [:]
    @State private var reorderDragID: String? = nil
    @State private var folderDragLocation: CGPoint = .zero
    @State private var panelFrame: CGRect = .zero
    /// 0 = parked on source tile, 1 = fully open at screen center.
    @State private var progress: CGFloat = 0
    @State private var isClosing = false
    @State private var closeGeneration = 0
    @FocusState private var nameFieldFocused: Bool

    private var folderTileWidth: CGFloat { GridMetrics.tileWidth * iconSizeLevel.multiplier }
    private var folderIconSize: CGFloat { 88 * iconSizeLevel.multiplier }
    private var folderTileHeight: CGFloat { 128 * iconSizeLevel.multiplier }

    private var panelWidth: CGFloat { 5 * folderTileWidth + 4 * 16 + 52 }

    /// Estimate resting panel height so we can map source tile → full panel scale.
    private var estimatedPanelHeight: CGFloat {
        let columns = 5
        let rows = max(1, min(4, (item.members.count + columns - 1) / columns))
        let titleBlock: CGFloat = 26 + 28
        let vSpacing: CGFloat = 20
        let grid =
            CGFloat(rows) * folderTileHeight
            + CGFloat(max(0, rows - 1)) * 24
            + 26
        return titleBlock + vSpacing + min(560, grid)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(folderTileWidth), spacing: 16), count: 5)
    }

    private var openSpring: Animation {
        .spring(response: 0.45, dampingFraction: 0.82)
    }

    private var closeSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.90)
    }

    /// Must outlast the close spring so we never remove the view while a 5-col
    /// panel is still visible at tile scale (that looked like a “stuck 5×4 folder”).
    private var closeDuration: TimeInterval { 0.42 }

    /// 0 at tile, 1 when fully open — how much of the 5-column popup is shown.
    /// Stays near 0 longer on close so the last frames are 3×3, not 5×4.
    private var expandedContentReveal: CGFloat {
        // Smoothstep from progress 0.22 → 0.72
        let t = (progress - 0.22) / 0.50
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }

    /// Motion blur while zooming (stronger near the tile, clear when fully open).
    private var motionBlurRadius: CGFloat {
        guard animate else { return 0 }
        return (1 - progress) * 10
    }

    /// Scale + offset that place the full-size panel over the source tile at `progress == 0`.
    private var zoomTransform: (scale: CGFloat, offset: CGSize) {
        let hasSource = sourceFrame.width > 2 && sourceFrame.height > 2
            && overlaySize.width > 2 && overlaySize.height > 2
        guard hasSource else {
            // Fallback: simple center scale when tile frame is unknown.
            let s = 0.40 + 0.60 * progress
            return (s, .zero)
        }

        let panelW = panelWidth
        let panelH = max(120, estimatedPanelHeight)
        let startScale = max(
            0.12,
            min(sourceFrame.width / panelW, sourceFrame.height / panelH)
        )
        let scale = startScale + (1 - startScale) * progress

        // ZStack centers the panel → resting layout center ≈ overlay center.
        let finalCenter = CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        let sourceCenter = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        let offset = CGSize(
            width: (sourceCenter.x - finalCenter.x) * (1 - progress),
            height: (sourceCenter.y - finalCenter.y) * (1 - progress)
        )
        return (scale, offset)
    }

    var body: some View {
        let zoom = zoomTransform
        let reveal = expandedContentReveal
        ZStack {
            // Real dismiss for outside-panel clicks happens in AppKit
            // (OverlayWindowController.handleMouseDown) — SwiftUI's onTapGesture
            // on a large, mostly-blank view is unreliable on macOS and would
            // otherwise need many clicks before registering. This stays as a
            // fallback for any input path that doesn't go through the monitor.
            Color.black.opacity(0.45)
                .opacity(Double(progress))
                // Soft blur on the dim layer while in transit.
                .blur(radius: motionBlurRadius * 0.35)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Jiggle mode: first blank tap exits edit, not the folder.
                    if editMode {
                        onCancelEditMode?()
                    } else {
                        beginDismiss()
                    }
                }
                .allowsHitTesting(progress > 0.85 && !isClosing)

            // Morphing shell: 3×3 tile look near the source, full 5-col popup when open.
            // Without this, scaling the 5-col layout down to the tile looked like the
            // folder “became” a 5×4 expanded panel.
            ZStack {
                compactTileLayer
                    .opacity(Double(1 - reveal))
                    .allowsHitTesting(false)

                expandedPanelLayer
                    .opacity(Double(reveal))
                    .allowsHitTesting(reveal > 0.9 && !isClosing)
            }
            .frame(width: panelWidth, height: max(120, estimatedPanelHeight))
            .compositingGroup()
            .blur(radius: motionBlurRadius)
            .scaleEffect(zoom.scale, anchor: .center)
            .offset(zoom.offset)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            // Hit-test frame must track the *visual* bounds after transform
                            // once fully open; during transit AppKit should not treat the
                            // shrinking shell as a persistent 5×4 folder on the grid.
                            reportPanelFrame(geo.frame(in: .named("overlay")), visual: zoom)
                        }
                        .onChange(of: progress) { _, _ in
                            reportPanelFrame(geo.frame(in: .named("overlay")), visual: zoomTransform)
                        }
                        .onChange(of: geo.frame(in: .named("overlay"))) { _, f in
                            reportPanelFrame(f, visual: zoomTransform)
                        }
                }
            )

            if let dragID = reorderDragID,
               let dragMember = item.members.first(where: { $0.id == dragID }),
               animate, reveal > 0.9 {
                RealAppIcon(record: dragMember)
                    .frame(width: folderIconSize, height: folderIconSize)
                    .scaleEffect(1.15)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                    .opacity(0.9)
                    .position(folderDragLocation)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .onAppear { playOpenAnimationIfNeeded() }
        .onChange(of: closeEpoch) { _, _ in
            beginDismiss()
        }
    }

    /// 3×3 closed-folder chrome — what the grid tile looks like.
    private var compactTileLayer: some View {
        let side = min(panelWidth, max(120, estimatedPanelHeight)) * 0.72
        return ZStack {
            RoundedRectangle(cornerRadius: min(28, side * 0.22), style: .continuous)
                .fill(Color.white.opacity(0.14))
            FolderTileView(members: item.members, size: side)
        }
        .frame(width: panelWidth, height: max(120, estimatedPanelHeight))
    }

    /// Full open folder panel (title + 5-column member grid).
    private var expandedPanelLayer: some View {
        VStack(spacing: 20) {
            titleView
                .padding(.top, 26)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(item.members) { member in
                        folderMemberCell(member: member)
                    }
                }
                .coordinateSpace(name: "folderGrid")
                .padding(.horizontal, 26)
                .padding(.bottom, 26)
                .animation(
                    animate ? .spring(response: 0.3, dampingFraction: 0.7) : nil,
                    value: item.members.map(\.id)
                )
            }
            .frame(maxHeight: 560)
        }
        .frame(width: panelWidth)
        .frame(maxHeight: max(120, estimatedPanelHeight))
        .background(
            Group {
                if let wallpaperImage {
                    Image(nsImage: wallpaperImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 50)
                        .overlay(Color.white.opacity(0.08))
                } else {
                    Rectangle().fill(.white.opacity(0.12))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    /// Publish panel frame for AppKit. While mostly closed, report `.zero` so a
    /// shrinking popup is not treated as a permanent hit target on the grid.
    private func reportPanelFrame(_ layoutFrame: CGRect, visual zoom: (scale: CGFloat, offset: CGSize)) {
        if progress < 0.5 || (isClosing && progress < 0.85) {
            if panelFrame != .zero {
                panelFrame = .zero
                onPanelFrameChanged?(.zero)
            }
            return
        }
        // Apply the same scale/offset the user sees (layout is pre-transform).
        var f = layoutFrame
        let cx = f.midX + zoom.offset.width
        let cy = f.midY + zoom.offset.height
        let w = f.width * zoom.scale
        let h = f.height * zoom.scale
        f = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        panelFrame = f
        onPanelFrameChanged?(f)
    }

    private func playOpenAnimationIfNeeded() {
        guard progress < 1, !isClosing else { return }
        if animate {
            progress = 0
            withAnimation(openSpring) {
                progress = 1
            }
        } else {
            progress = 1
        }
    }

    /// Zoom back to the source tile (as 3×3), then remove the popup from the tree.
    private func beginDismiss() {
        guard !isClosing else { return }

        guard animate, progress > 0.01 else {
            finishDismiss()
            return
        }

        isClosing = true
        closeGeneration &+= 1
        let generation = closeGeneration
        // Clear hit frame immediately so AppKit never “sticks” on a tiny 5×4.
        panelFrame = .zero
        onPanelFrameChanged?(.zero)
        withAnimation(closeSpring) {
            progress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDuration) {
            guard generation == closeGeneration else { return }
            finishDismiss()
        }
    }

    private func finishDismiss() {
        if let onCloseAnimationFinished {
            onCloseAnimationFinished()
        } else {
            onClose()
        }
    }

    @ViewBuilder
    private func folderMemberCell(member: AppRecord) -> some View {
        let displayItem = LaunchpadDisplayItem(
            id: member.id,
            title: member.name,
            kind: .app(member)
        )
        let isBeingDragged = (editDragID == member.id && !leftFolder) || reorderDragID == member.id
        let dragTrans = isBeingDragged ? editDragTranslation : .zero
        let jiggleAmp: Double = {
            var generator = SeededGenerator(seed: UInt64(member.id.hashValue & 0xFFFFFFFF))
            return Double.random(in: 0.2...0.35, using: &generator)
        }()

        TimelineView(.animation(minimumInterval: 0.05, paused: !editMode || isBeingDragged)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let angle = (editMode && !isBeingDragged) ? sin(phase * 22.0) * jiggleAmp : 0.0
            AppIconView(
                item: displayItem,
                iconSize: folderIconSize,
                tileWidth: folderTileWidth,
                tileHeight: folderTileHeight
                // No onActivate/onDrag* — folder cell owns tap + drag below.
            )
                .scaleEffect(isBeingDragged ? 1.1 : 1.0)
                .shadow(color: isBeingDragged ? .black.opacity(0.4) : .clear, radius: 14, y: 6)
                .rotationEffect(.degrees(angle))
                .offset(dragTrans)
                .opacity(leftFolder && editDragID == member.id ? 0 : (reorderDragID == member.id && animate ? 0 : 1))
                .zIndex(isBeingDragged ? 100 : 0)
        }
            .contentShape(Rectangle())
            .modifier(TileTrashMenu(
                item: displayItem,
                onTrash: { _ in onTrash(member) },
                editMode: editMode
            ))
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4, maximumDistance: 6)
                    .onEnded { _ in
                        onEnterEditMode?()
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("overlay"))
                    .onChanged { value in
                        if leftFolder { return }

                        let distance = hypot(value.translation.width, value.translation.height)
                        DiagLog.write("folder drag onChanged distance=\(distance)")
                        guard distance >= 6 else { return }

                        // panelFrame is .zero until first layout — must not treat
                        // that as "outside" or every drag immediately drag-outs.
                        let outsidePanel = panelFrame.width > 1
                            && panelFrame.height > 1
                            && !panelFrame.insetBy(dx: -20, dy: -20).contains(value.location)
                        if outsidePanel {
                            leftFolder = true
                            reorderDragID = nil
                            NotificationCenter.default.post(
                                name: .inceptLaunchEditDragChanged,
                                object: EditDragUpdate(id: member.id, translation: value.translation)
                            )
                            onDragOutBegan?(member.id, value.location)
                        } else {
                            reorderDragID = member.id
                            folderDragLocation = value.location
                            let targetIndex = computeReorderIndex(
                                dragID: member.id,
                                location: value.location
                            )
                            if let targetIndex,
                               let currentIndex = item.members.firstIndex(where: { $0.id == member.id }),
                               targetIndex != currentIndex {
                                onReorder?(member.id, targetIndex)
                            }
                        }
                    }
                    .onEnded { value in
                        let distance = hypot(value.translation.width, value.translation.height)
                        DiagLog.write("folder drag onEnded distance=\(distance) leftFolder=\(leftFolder)")
                        if distance < 6 {
                            if editMode {
                                onCancelEditMode?()
                            } else {
                                onLaunch(member)
                            }
                        } else if !leftFolder {
                            reorderDragID = nil
                            folderDragLocation = .zero
                            onReorderEnded?()
                            NotificationCenter.default.post(
                                name: .inceptLaunchEditDragEnded,
                                object: nil
                            )
                        }
                        leftFolder = false
                    }
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            memberFrames[member.id] = geo.frame(in: .named("overlay"))
                        }
                        .onChange(of: geo.frame(in: .named("overlay"))) { _, newFrame in
                            memberFrames[member.id] = newFrame
                        }
                }
            )
    }

    @ViewBuilder
    private var titleView: some View {
        if isEditingName {
            TextField("文件夹名称", text: $draftName)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .focused($nameFieldFocused)
                .onSubmit { commitName() }
                .onChange(of: nameFieldFocused) { _, focused in
                    if !focused { commitName() }
                }
                .frame(width: 320)
        } else {
            Text(item.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    draftName = item.title
                    isEditingName = true
                    nameFieldFocused = true
                }
        }
    }

    private func computeReorderIndex(dragID: String, location: CGPoint) -> Int? {
        let sorted = item.members.enumerated()
            .compactMap { (index, member) -> (Int, CGRect)? in
                guard let frame = memberFrames[member.id] else { return nil }
                return (index, frame)
            }
            .sorted { $0.1.minY < $1.1.minY || ($0.1.minY == $1.1.minY && $0.1.minX < $1.1.minX) }

        for (index, frame) in sorted {
            if location.x < frame.midX && location.y < frame.maxY {
                return index
            }
        }
        return item.members.count - 1
    }

    private func commitName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != item.title {
            onRename(trimmed)
        }
        isEditingName = false
    }
}

extension Notification.Name {
    static let inceptLaunchFloatingDragMoved = Notification.Name("inceptLaunchFloatingDragMoved")
}

/// Deterministic random number generator seeded by a UInt64 value.
/// Used to give each tile a stable random jiggle angle.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdead_beef : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

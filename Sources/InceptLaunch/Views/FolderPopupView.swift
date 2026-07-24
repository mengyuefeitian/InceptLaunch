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
    var animate: Bool = true

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

    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var leftFolder = false
    @FocusState private var nameFieldFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(GridMetrics.tileWidth), spacing: 16), count: 5)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode {
                        onCancelEditMode?()
                    } else {
                        onClose()
                    }
                }

            VStack(spacing: 20) {
                titleView
                    .padding(.top, 26)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(item.members) { member in
                            folderMemberCell(member: member)
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 26)
                }
                .frame(maxHeight: 560)
            }
            .frame(width: 780)
            .liquidGlass(cornerRadius: 32, fallbackOpacity: 0.22)
            .transition(
                animate
                    ? .scale(scale: 0.6).combined(with: .opacity)
                    : .opacity
            )
        }
    }

    @ViewBuilder
    private func folderMemberCell(member: AppRecord) -> some View {
        let displayItem = LaunchpadDisplayItem(
            id: member.id,
            title: member.name,
            kind: .app(member)
        )
        let isBeingDragged = editDragID == member.id && !leftFolder
        let dragTrans = isBeingDragged ? editDragTranslation : .zero
        let jiggleAmp: Double = {
            var generator = SeededGenerator(seed: UInt64(member.id.hashValue & 0xFFFFFFFF))
            return Double.random(in: 0.2...0.35, using: &generator)
        }()

        TimelineView(.animation(minimumInterval: 0.05, paused: !editMode || isBeingDragged)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let angle = (editMode && !isBeingDragged) ? sin(phase * 22.0) * jiggleAmp : 0.0
            AppIconView(item: displayItem, iconSize: 88, tileHeight: 128)
                .scaleEffect(isBeingDragged ? 1.1 : 1.0)
                .shadow(color: isBeingDragged ? .black.opacity(0.4) : .clear, radius: 14, y: 6)
                .rotationEffect(.degrees(angle))
                .offset(dragTrans)
                .opacity(leftFolder && editDragID == member.id ? 0 : 1)
                .zIndex(isBeingDragged ? 100 : 0)
        }
            .modifier(TileTrashMenu(
                item: displayItem,
                onTrash: { _ in onTrash(member) },
                editMode: editMode
            ))
            .onTapGesture {
                if editMode {
                    onCancelEditMode?()
                } else {
                    onLaunch(member)
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4, maximumDistance: 6)
                    .onEnded { _ in
                        onEnterEditMode?()
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named("overlay"))
                    .onChanged { value in
                        // Once we've handed off to the AppKit floating-drag
                        // monitor, stop touching layout from this gesture —
                        // the popup is about to unmount.
                        if leftFolder { return }

                        let distance = hypot(value.translation.width, value.translation.height)
                        NotificationCenter.default.post(
                            name: .inceptLaunchEditDragChanged,
                            object: EditDragUpdate(id: member.id, translation: value.translation)
                        )

                        // Leave the folder once the pointer travels far enough.
                        // Closing the popup kills this SwiftUI gesture; the
                        // AppKit monitor continues tracking mouse drag/up.
                        if distance > 90 {
                            leftFolder = true
                            onDragOutBegan?(member.id, value.location)
                        }
                    }
                    .onEnded { value in
                        // If we never left the folder, just clear the local drag.
                        // If we did leave, AppKit monitor owns mouse-up / drop.
                        if !leftFolder {
                            NotificationCenter.default.post(
                                name: .inceptLaunchEditDragEnded,
                                object: nil
                            )
                        }
                        leftFolder = false
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

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
    /// Called when an app is dragged out of the folder. Returns the app to the grid.
    var onDragOut: ((String) -> Void)? = nil

    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var jiggle = false
    @FocusState private var nameFieldFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(GridMetrics.tileWidth), spacing: 16), count: 5)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode {
                        onEnterEditMode?()
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
    private func folderMemberCell(member: AppRecord) -> some View {
        let displayItem = LaunchpadDisplayItem(
            id: member.id,
            title: member.name,
            kind: .app(member)
        )
        let isBeingDragged = editMode && editDragID == member.id
        let dragTrans = isBeingDragged ? editDragTranslation : .zero
        // Random jiggle angle per cell (stable across renders)
        let jiggleAngle: Double = {
            var generator = SeededGenerator(seed: UInt64(member.id.hashValue & 0xFFFFFFFF))
            return Double.random(in: -2.0...2.0, using: &generator)
        }()

        AppIconView(item: displayItem, iconSize: 88, tileHeight: 128)
            .scaleEffect(isBeingDragged ? 0.85 : 1.0)
            .shadow(color: isBeingDragged ? .black.opacity(0.35) : .clear, radius: 10, y: 5)
            .rotationEffect(
                editMode && !isBeingDragged
                    ? (jiggle ? .degrees(jiggleAngle) : .degrees(-jiggleAngle))
                    : .degrees(0)
            )
            .offset(dragTrans)
            .modifier(TileTrashMenu(
                item: displayItem,
                onTrash: { _ in onTrash(member) },
                editMode: editMode
            ))
            .onTapGesture {
                if editMode {
                    onEnterEditMode?()
                } else {
                    onLaunch(member)
                }
            }
            .onLongPressGesture(minimumDuration: 0.3) {
                if !editMode {
                    onEnterEditMode?()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        NotificationCenter.default.post(
                            name: .inceptLaunchEditDragChanged,
                            object: EditDragUpdate(id: member.id, translation: value.translation)
                        )
                    }
                    .onEnded { value in
                        // If dragged far enough, remove from folder
                        let distance = sqrt(value.translation.width * value.translation.width
                                          + value.translation.height * value.translation.height)
                        if distance > 60 {
                            onDragOut?(member.id)
                        }
                        NotificationCenter.default.post(
                            name: .inceptLaunchEditDragEnded,
                            object: nil
                        )
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

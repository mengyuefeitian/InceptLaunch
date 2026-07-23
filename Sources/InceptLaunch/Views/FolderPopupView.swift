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

    @State private var isEditingName = false
    @State private var draftName = ""
    @FocusState private var nameFieldFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(GridMetrics.tileWidth), spacing: 16), count: 5)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 20) {
                titleView
                    .padding(.top, 26)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(item.members) { member in
                            AppIconView(item: LaunchpadDisplayItem(
                                id: member.id,
                                title: member.name,
                                kind: .app(member)
                            ), iconSize: 88, tileHeight: 128)
                            .modifier(TileTrashMenu(
                                item: LaunchpadDisplayItem(
                                    id: member.id,
                                    title: member.name,
                                    kind: .app(member)
                                ),
                                onTrash: { _ in onTrash(member) }
                            ))
                            .onTapGesture { onLaunch(member) }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 26)
                }
                .frame(maxHeight: 560)
            }
            .frame(width: 780)
            .liquidGlass(cornerRadius: 32, fallbackOpacity: 0.22)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
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

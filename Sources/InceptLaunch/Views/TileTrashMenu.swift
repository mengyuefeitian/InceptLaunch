import AppKit
import SwiftUI

/// Launchpad-style context menu for tiles: apps get "移到废纸篓", folders get
/// enlarge/shrink. Long-press pops the same menu natively.
struct TileTrashMenu: ViewModifier {
    let item: LaunchpadDisplayItem
    let onTrash: (LaunchpadDisplayItem) -> Void
    var isEnlarged: Bool = false
    var onEnlarge: ((LaunchpadDisplayItem) -> Void)?
    var onShrink: ((LaunchpadDisplayItem) -> Void)?

    private var isApp: Bool {
        if case .app = item.kind { return true }
        return false
    }

    private var isFolder: Bool {
        if case .folder = item.kind { return true }
        return false
    }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if isApp {
                    Button(role: .destructive) {
                        onTrash(item)
                    } label: {
                        Label("移到废纸篓", systemImage: "trash")
                    }
                }
                if isFolder {
                    if isEnlarged {
                        Button {
                            onShrink?(item)
                        } label: {
                            Label("缩小文件夹", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                    } else {
                        Button {
                            onEnlarge?(item)
                        } label: {
                            Label("放大文件夹", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                popUpNativeMenu()
            }
    }

    private func popUpNativeMenu() {
        guard NSEvent.pressedMouseButtons & 0x2 == 0 else { return }
        showWhenReleased()
    }

    private func showWhenReleased() {
        if NSEvent.pressedMouseButtons != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                showWhenReleased()
            }
            return
        }
        showMenu()
    }

    private func showMenu() {
        let handler = MenuActionHandler()
        let menu = NSMenu()

        if isApp {
            let trashItem = NSMenuItem(
                title: "移到废纸篓",
                action: #selector(MenuActionHandler.handle(_:)),
                keyEquivalent: ""
            )
            trashItem.target = handler
            trashItem.representedObject = "trash"
            menu.addItem(trashItem)
        }

        if isFolder {
            let title = isEnlarged ? "缩小文件夹" : "放大文件夹"
            let action = isEnlarged ? "shrink" : "enlarge"
            let folderItem = NSMenuItem(
                title: title,
                action: #selector(MenuActionHandler.handle(_:)),
                keyEquivalent: ""
            )
            folderItem.target = handler
            folderItem.representedObject = action
            menu.addItem(folderItem)
        }

        guard menu.items.count > 0 else { return }
        let cursor = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: CGPoint(x: cursor.x + 8, y: cursor.y - 8), in: nil)
        switch handler.selectedAction {
        case "trash": onTrash(item)
        case "enlarge": onEnlarge?(item)
        case "shrink": onShrink?(item)
        default: break
        }
    }
}

private final class MenuActionHandler: NSObject {
    var selectedAction: String?

    @objc func handle(_ sender: NSMenuItem) {
        selectedAction = sender.representedObject as? String
    }
}

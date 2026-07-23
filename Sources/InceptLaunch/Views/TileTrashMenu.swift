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
    var onHide: ((LaunchpadDisplayItem) -> Void)?

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
                    Button {
                        onHide?(item)
                    } label: {
                        Label(Localizer.t("menu.hide"), systemImage: "eye.slash")
                    }
                    Button(role: .destructive) {
                        onTrash(item)
                    } label: {
                        Label(Localizer.t("menu.trash"), systemImage: "trash")
                    }
                }
                if isFolder {
                    if isEnlarged {
                        Button {
                            onShrink?(item)
                        } label: {
                            Label(Localizer.t("menu.shrinkFolder"), systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                    } else {
                        Button {
                            onEnlarge?(item)
                        } label: {
                            Label(Localizer.t("menu.enlargeFolder"), systemImage: "arrow.up.left.and.arrow.down.right")
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
            let hideItem = NSMenuItem(
                title: Localizer.t("menu.hide"),
                action: #selector(MenuActionHandler.handle(_:)),
                keyEquivalent: ""
            )
            hideItem.target = handler
            hideItem.representedObject = "hide"
            menu.addItem(hideItem)

            let trashItem = NSMenuItem(
                title: Localizer.t("menu.trash"),
                action: #selector(MenuActionHandler.handle(_:)),
                keyEquivalent: ""
            )
            trashItem.target = handler
            trashItem.representedObject = "trash"
            menu.addItem(trashItem)
        }

        if isFolder {
            let title = isEnlarged ? Localizer.t("menu.shrinkFolder") : Localizer.t("menu.enlargeFolder")
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
        case "hide": onHide?(item)
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

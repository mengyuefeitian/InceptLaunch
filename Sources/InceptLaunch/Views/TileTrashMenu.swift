import AppKit
import SwiftUI

/// Launchpad-style delete affordance for app tiles: pressing and holding
/// (trackpad/mouse) or right-clicking pops a menu offering to move the app to
/// the Trash. Only plain app tiles get the menu; folders are left alone.
struct TileTrashMenu: ViewModifier {
    let item: LaunchpadDisplayItem
    let onTrash: (LaunchpadDisplayItem) -> Void

    private var isApp: Bool {
        if case .app = item.kind { return true }
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
            }
            // Long-press pops the same menu natively. onLongPressGesture
            // arbitrates against onTapGesture (a simultaneousGesture long
            // press never fires once a tap gesture is installed), and its
            // 10pt maximumDistance keeps drags from triggering it.
            .onLongPressGesture(minimumDuration: 0.5) {
                guard isApp else { return }
                popUpNativeMenu()
            }
    }

    private func popUpNativeMenu() {
        // Right-button holds are covered by the contextMenu above; showing a
        // second menu would clash with it.
        guard NSEvent.pressedMouseButtons & 0x2 == 0 else { return }
        showWhenReleased()
    }

    /// The long-press gesture fires while the button is still held down. If
    /// the menu popped up right away, the eventual release would land on the
    /// menu and dismiss it (or worse, pick an item). Wait for the button to
    /// come up first so the menu stays open until a deliberate click.
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
        let trashItem = NSMenuItem(
            title: "移到废纸篓",
            action: #selector(MenuActionHandler.handle(_:)),
            keyEquivalent: ""
        )
        trashItem.target = handler
        trashItem.representedObject = "trash"
        menu.addItem(trashItem)
        // A nil view positions the menu at screen coordinates, which is where
        // NSEvent.mouseLocation lives. Offset below-right of the cursor so no
        // item starts out highlighted under it. popUp blocks until the user
        // chooses or dismisses the menu.
        let cursor = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: CGPoint(x: cursor.x + 8, y: cursor.y - 8), in: nil)
        if handler.selectedAction == "trash" {
            onTrash(item)
        }
    }
}

private final class MenuActionHandler: NSObject {
    var selectedAction: String?

    @objc func handle(_ sender: NSMenuItem) {
        selectedAction = sender.representedObject as? String
    }
}

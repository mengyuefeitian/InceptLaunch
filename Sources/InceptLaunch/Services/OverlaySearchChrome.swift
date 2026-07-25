import AppKit

private final class VerticallyCenteredCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let contentHeight = cellSize(forBounds: rect).height
        let y = (rect.height - contentHeight) / 2
        return NSRect(x: rect.origin.x, y: y, width: rect.width, height: contentHeight)
    }
}

/// AppKit search field hosted directly on the overlay window.
/// SwiftUI `TextField` inside a borderless full-screen `NSHostingView` has
/// repeatedly failed to paint for users; a real `NSTextField` always shows.
@MainActor
final class OverlaySearchChrome: NSObject, NSTextFieldDelegate {
    /// Height reserved at the top of the overlay for the search chrome
    /// (padding + field). ContentView should leave the same spacer.
    /// Tall enough that the capsule sits mid-way between the menu bar and
    /// the first icon row (not glued under the menu bar).
    static let chromeHeight: CGFloat = 128
    static let fieldWidth: CGFloat = 420
    static let fieldHeight: CGFloat = 36
    /// Distance from the top of the screen down to the search capsule.
    static let topPadding: CGFloat = 78

    private let container = NSView()
    private let background = NSView()
    private let icon = NSImageView()
    private let field = NSTextField(string: "")
    private var onTextChange: ((String) -> Void)?

    var view: NSView { container }

    func install(
        on parent: NSView,
        onTextChange: @escaping (String) -> Void
    ) {
        self.onTextChange = onTextChange

        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
        background.layer?.cornerRadius = Self.fieldHeight / 2
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
        background.layer?.masksToBounds = true

        let loupe = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "Search"
        )
        icon.image = loupe
        icon.contentTintColor = NSColor.white.withAlphaComponent(0.85)
        icon.imageScaling = .scaleProportionallyDown

        field.placeholderString = Localizer.t("search.placeholder")
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        field.textColor = .white
        field.delegate = self
        field.placeholderAttributedString = NSAttributedString(
            string: Localizer.t("search.placeholder"),
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.45),
                .font: NSFont.systemFont(ofSize: 15, weight: .medium)
            ]
        )
        let centeredCell = VerticallyCenteredCell()
        centeredCell.font = field.font
        centeredCell.textColor = .white
        centeredCell.placeholderAttributedString = field.placeholderAttributedString
        field.cell = centeredCell

        container.addSubview(background)
        background.addSubview(icon)
        background.addSubview(field)
        parent.addSubview(container)

        layout(in: parent.bounds)
        container.autoresizingMask = [.width, .minYMargin]
    }

    func layout(in parentBounds: NSRect) {
        // AppKit origin is bottom-left. Chrome strip sits at the top of the window.
        container.frame = NSRect(
            x: 0,
            y: parentBounds.height - Self.chromeHeight,
            width: parentBounds.width,
            height: Self.chromeHeight
        )

        // Capsule sits `topPadding` down from the window top (container is the
        // top chromeHeight band, so from top of container = topPadding).
        // AppKit origin is bottom-left of the container:
        let fieldOriginY = max(8, Self.chromeHeight - Self.topPadding - Self.fieldHeight)
        let fieldX = (parentBounds.width - Self.fieldWidth) / 2
        background.frame = NSRect(
            x: fieldX,
            y: fieldOriginY,
            width: Self.fieldWidth,
            height: Self.fieldHeight
        )

        icon.frame = NSRect(x: 14, y: (Self.fieldHeight - 16) / 2, width: 16, height: 16)
        field.frame = NSRect(x: 38, y: 0, width: Self.fieldWidth - 52, height: Self.fieldHeight)
    }

    func setText(_ text: String) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    /// Feed a key event into the field after focusing it (preserves IME).
    func interpretKeyEvent(_ event: NSEvent) {
        focus()
        field.interpretKeyEvents([event])
        // Some plain inserts update via interpret; sync binding either way.
        onTextChange?(field.stringValue)
    }

    func focus() {
        guard let window = field.window ?? container.window else { return }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }

    func blur() {
        field.window?.makeFirstResponder(nil)
    }

    func refreshPlaceholder() {
        let text = Localizer.t("search.placeholder")
        field.placeholderString = text
        field.placeholderAttributedString = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.45),
                .font: NSFont.systemFont(ofSize: 15, weight: .medium)
            ]
        )
    }

    func remove() {
        container.removeFromSuperview()
        onTextChange = nil
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        onTextChange?(field.stringValue)
    }
}

import AppKit
import SwiftUI

/// Vertically centers text / field-editor inside a tall search capsule.
private final class VerticallyCenteredCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        let delta = newRect.height - textHeight
        if delta > 0 {
            newRect.origin.y += delta / 2
            newRect.size.height = textHeight
        }
        return newRect
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}

/// Painted frosted capsule — wallpaper blur + light wash. No glassEffect.
private struct SearchChromeFrostBackground: View {
    var body: some View {
        Color.clear
            .frame(
                width: OverlaySearchChrome.fieldWidth,
                height: OverlaySearchChrome.fieldHeight
            )
            .wallpaperFrostCapsule(blurRadius: 28, washOpacity: 0.16)
    }
}

/// AppKit search field on the overlay. Background is painted frost; the field
/// is a real `NSTextField` so typing / IME stay reliable.
@MainActor
final class OverlaySearchChrome: NSObject, NSTextFieldDelegate {
    static let chromeHeight: CGFloat = 128
    static let fieldWidth: CGFloat = 420
    static let fieldHeight: CGFloat = 36
    static let topPadding: CGFloat = 78

    private let container = NSView()
    private let frostHost = NSHostingView(rootView: SearchChromeFrostBackground())
    private let content = NSView()
    private let icon = NSImageView()
    private let field = NSTextField(string: "")
    private var onTextChange: ((String) -> Void)?

    var view: NSView { container }

    var allowsTextInput: Bool {
        field.isEditable && field.isSelectable && field.isEnabled
    }

    var usesGlassBackground: Bool {
        frostHost.superview != nil
    }

    func install(
        on parent: NSView,
        onTextChange: @escaping (String) -> Void
    ) {
        self.onTextChange = onTextChange

        // Hosting view must be transparent so frost paints, not a black plate.
        frostHost.frame = NSRect(
            origin: .zero,
            size: CGSize(width: Self.fieldWidth, height: Self.fieldHeight)
        )
        frostHost.wantsLayer = true
        frostHost.layer?.backgroundColor = NSColor.clear.cgColor
        frostHost.layer?.isOpaque = false

        field.placeholderString = Localizer.t("search.placeholder")
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        field.textColor = .white
        field.delegate = self
        field.placeholderAttributedString = Self.placeholderAttributes(
            Localizer.t("search.placeholder")
        )

        let centeredCell = VerticallyCenteredCell()
        centeredCell.font = field.font
        centeredCell.textColor = .white
        centeredCell.placeholderAttributedString = field.placeholderAttributedString
        centeredCell.isEditable = true
        centeredCell.isSelectable = true
        centeredCell.isEnabled = true
        centeredCell.isBordered = false
        centeredCell.isBezeled = false
        centeredCell.drawsBackground = false
        centeredCell.focusRingType = .none
        field.cell = centeredCell

        let loupe = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "Search"
        )
        icon.image = loupe
        icon.contentTintColor = NSColor.white.withAlphaComponent(0.92)
        icon.imageScaling = .scaleProportionallyDown

        content.addSubview(icon)
        content.addSubview(field)

        container.addSubview(frostHost)
        container.addSubview(content)
        parent.addSubview(container)

        layout(in: parent.bounds)
        container.autoresizingMask = [.width, .minYMargin]
    }

    func layout(in parentBounds: NSRect) {
        container.frame = NSRect(
            x: 0,
            y: parentBounds.height - Self.chromeHeight,
            width: parentBounds.width,
            height: Self.chromeHeight
        )

        let fieldOriginY = max(8, Self.chromeHeight - Self.topPadding - Self.fieldHeight)
        let fieldX = (parentBounds.width - Self.fieldWidth) / 2
        let capsule = NSRect(
            x: fieldX,
            y: fieldOriginY,
            width: Self.fieldWidth,
            height: Self.fieldHeight
        )

        frostHost.frame = capsule
        content.frame = capsule

        icon.frame = NSRect(x: 14, y: (Self.fieldHeight - 16) / 2, width: 16, height: 16)
        field.frame = NSRect(x: 38, y: 0, width: Self.fieldWidth - 52, height: Self.fieldHeight)
    }

    func setText(_ text: String) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func interpretKeyEvent(_ event: NSEvent) {
        focus()
        field.interpretKeyEvents([event])
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
        let attributed = Self.placeholderAttributes(text)
        field.placeholderAttributedString = attributed
        if let cell = field.cell as? NSTextFieldCell {
            cell.placeholderAttributedString = attributed
        }
    }

    func remove() {
        container.removeFromSuperview()
        onTextChange = nil
    }

    private static func placeholderAttributes(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.55),
                .font: NSFont.systemFont(ofSize: 15, weight: .medium)
            ]
        )
    }

    func controlTextDidChange(_ obj: Notification) {
        onTextChange?(field.stringValue)
    }
}

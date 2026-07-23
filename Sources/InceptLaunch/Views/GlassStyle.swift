import SwiftUI

/// Applies macOS 26 Liquid Glass to a view with a graceful fallback to
/// material fills on earlier systems.
struct LiquidGlassModifier<S: InsettableShape>: ViewModifier {
    var shape: S
    var cornerRadius: CGFloat = 24
    var fallbackOpacity: Double = 0.16

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(
                    shape.fill(.white.opacity(fallbackOpacity))
                )
                .overlay(
                    shape.strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

extension View {
    /// Liquid Glass surface for rounded-rectangle containers (folders, popups).
    func liquidGlass(cornerRadius: CGFloat = 24, fallbackOpacity: Double = 0.16) -> some View {
        modifier(LiquidGlassModifier(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            cornerRadius: cornerRadius,
            fallbackOpacity: fallbackOpacity
        ))
    }

    /// Liquid Glass surface for capsule shapes (search field).
    func liquidGlassCapsule(fallbackOpacity: Double = 0.16) -> some View {
        modifier(LiquidGlassModifier(
            shape: Capsule(),
            fallbackOpacity: fallbackOpacity
        ))
    }
}

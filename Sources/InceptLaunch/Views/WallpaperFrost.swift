import AppKit
import SwiftUI

/// Translucent frosted surface that always looks right on the Launchpad
/// wallpaper. Does **not** use `glassEffect` / `NSVisualEffectView` — those
/// collapse to opaque black in this borderless full-screen overlay.
///
/// Same recipe as `FolderPopupView`: blur the desktop wallpaper, light white
/// wash, white edge. Guaranteed see-through, never a solid dark slab.
struct WallpaperFrost<S: InsettableShape>: View {
    var shape: S
    var blurRadius: CGFloat = 40
    var washOpacity: Double = 0.14
    var strokeOpacity: Double = 0.28
    /// Optional override (e.g. tests / previews). Defaults to live desktop capture.
    var wallpaper: NSImage? = nil

    private var image: NSImage? {
        wallpaper ?? DesktopWallpaperCapture.currentImage
    }

    var body: some View {
        shape
            .fill(Color.clear)
            .background {
                ZStack {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: blurRadius)
                            // Slight scale so blur edges don't show empty fringes.
                            .scaleEffect(1.12)
                    }
                    // Light frosted wash — white, NOT black.
                    shape.fill(Color.white.opacity(image == nil ? 0.22 : washOpacity))
                }
                .clipShape(shape)
            }
            .overlay(
                shape.strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
            .clipShape(shape)
    }
}

extension View {
    /// Folder / panel frosted rounded rect (popup, enlarged tile).
    func wallpaperFrost(
        cornerRadius: CGFloat = 28,
        blurRadius: CGFloat = 40,
        washOpacity: Double = 0.14
    ) -> some View {
        background {
            WallpaperFrost(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                blurRadius: blurRadius,
                washOpacity: washOpacity
            )
        }
    }

    /// Search capsule frost.
    func wallpaperFrostCapsule(
        blurRadius: CGFloat = 28,
        washOpacity: Double = 0.16
    ) -> some View {
        background {
            WallpaperFrost(
                shape: Capsule(style: .continuous),
                blurRadius: blurRadius,
                washOpacity: washOpacity
            )
        }
    }
}

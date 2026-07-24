import SwiftUI

struct SearchFieldView: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
                .font(.system(size: 16, weight: .medium))
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .foregroundStyle(.white)
                .tint(.white)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.black.opacity(0.35)))
        .liquidGlassCapsule(fallbackOpacity: 0.18)
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .frame(maxWidth: 420)
    }
}

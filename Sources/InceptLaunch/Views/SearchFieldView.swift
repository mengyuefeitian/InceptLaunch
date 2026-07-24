import SwiftUI

struct SearchFieldView: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
                .font(.system(size: 15, weight: .medium))
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .foregroundStyle(.white)
                .tint(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .liquidGlassCapsule(fallbackOpacity: 0.18)
        .frame(maxWidth: 420)
    }
}

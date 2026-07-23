import SwiftUI

struct SearchFieldView: View {
    @Binding var text: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        TextField("Search", text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .liquidGlassCapsule(fallbackOpacity: 0.12)
            .frame(maxWidth: 420)
    }
}

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
            .background(.regularMaterial, in: Capsule())
            .frame(maxWidth: 420)
    }
}

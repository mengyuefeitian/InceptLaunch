import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreferences.default
    private let preferencesStore = PreferencesStore()

    var body: some View {
        Form {
            Section("Launch") {
                TextField("Global shortcut", text: $preferences.hotKey)
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $preferences.showMenuBarIcon)
                Toggle("Show Dock icon", isOn: $preferences.showDockIcon)
            }

            Section("Appearance") {
                Slider(value: $preferences.backgroundBlur, in: 0...1) {
                    Text("Background blur")
                }
                Toggle("Reduce motion", isOn: $preferences.reduceMotion)
                VStack(alignment: .leading, spacing: 8) {
                    Text("App icon").font(.headline)
                    HStack(spacing: 12) {
                        ForEach(UserPreferences.AppIconStyle.allCases, id: \.self) { style in
                            IconThumbnailView(
                                style: style,
                                isSelected: preferences.appIconStyle == style
                            )
                            .onTapGesture {
                                preferences.appIconStyle = style
                                IconSwitcher.apply(style)
                                savePreferences()
                            }
                        }
                    }
                }
            }

            Section("Apps") {
                Toggle("Show system applications", isOn: $preferences.showSystemApplications)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 460)
        .onAppear {
            preferences = (try? preferencesStore.load()) ?? .default
        }
        .onChange(of: preferences.hotKey) { _, _ in savePreferences() }
        .onChange(of: preferences.launchAtLogin) { _, _ in savePreferences() }
        .onChange(of: preferences.showMenuBarIcon) { _, _ in savePreferences() }
        .onChange(of: preferences.showDockIcon) { _, _ in savePreferences() }
        .onChange(of: preferences.backgroundBlur) { _, _ in savePreferences() }
        .onChange(of: preferences.reduceMotion) { _, _ in savePreferences() }
        .onChange(of: preferences.showSystemApplications) { _, _ in savePreferences() }
    }

    private func savePreferences() {
        try? preferencesStore.save(preferences)
    }
}

/// A clickable thumbnail that previews an app icon variant.
/// Shows a rounded-square image with a blue border when selected.
struct IconThumbnailView: View {
    let style: UserPreferences.AppIconStyle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(style.thumbnailName)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                )
                .shadow(radius: isSelected ? 3 : 1)
            Text(style.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
    }
}

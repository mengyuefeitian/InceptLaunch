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
                Picker("App icon", selection: $preferences.appIconStyle) {
                    ForEach(UserPreferences.AppIconStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .onChange(of: preferences.appIconStyle) { _, newValue in
                    IconSwitcher.apply(newValue)
                    savePreferences()
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

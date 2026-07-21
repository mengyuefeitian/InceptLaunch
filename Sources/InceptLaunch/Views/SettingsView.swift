import SwiftUI

struct SettingsView: View {
    @State private var preferences = UserPreferences.default

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
            }

            Section("Apps") {
                Toggle("Show system applications", isOn: $preferences.showSystemApplications)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 420)
    }
}

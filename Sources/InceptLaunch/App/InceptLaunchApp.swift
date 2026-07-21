import SwiftUI

enum AppIdentity {
    static let name = "InceptLaunch"
    static let bundleIdentifier = "com.inceptlaunch.InceptLaunch"
}

@main
struct InceptLaunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(AppIdentity.name) {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
        }
    }
}

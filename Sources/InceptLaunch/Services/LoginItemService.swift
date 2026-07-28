import ServiceManagement

/// What, if anything, must change in the system's login-item registration
/// to match the user's `launchAtLogin` preference.
enum LoginItemAction: Equatable {
    case register
    case unregister
    case none
}

/// Wraps `SMAppService.mainApp` so toggling "Launch at Login" in Settings
/// actually registers/unregisters the app with the system, instead of only
/// persisting a preference flag that macOS never sees.
enum LoginItemService {
    /// Pure decision logic, kept separate from the `SMAppService` call so it
    /// can be unit tested without touching real system state.
    static func action(for enabled: Bool, currentStatus: SMAppService.Status) -> LoginItemAction {
        switch (enabled, currentStatus) {
        case (true, .enabled):
            return .none
        case (true, _):
            return .register
        case (false, .notRegistered):
            return .none
        case (false, _):
            return .unregister
        }
    }

    /// Applies the user's preference to the system login item list.
    /// Failures (e.g. the user declines in System Settings) are logged, not
    /// thrown, so a login-item failure never blocks the rest of Settings.
    static func apply(_ enabled: Bool) {
        let status = SMAppService.mainApp.status
        switch action(for: enabled, currentStatus: status) {
        case .register:
            do {
                try SMAppService.mainApp.register()
            } catch {
                DiagLog.write("SMAppService.register failed: \(error)")
            }
        case .unregister:
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                DiagLog.write("SMAppService.unregister failed: \(error)")
            }
        case .none:
            break
        }
    }
}

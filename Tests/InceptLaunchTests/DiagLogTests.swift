import Testing
@testable import InceptLaunch

/// `write()` always no-ops under `swift test` (see `DiagLog.isRunningTests`)
/// so these only cover the on/off switch itself, not actual file writes.

@Test func diagLogDefaultsToEnabled() throws {
    #expect(DiagLog.isEnabled == true)
}

@Test func diagLogConfigureTogglesEnabledState() throws {
    DiagLog.configure(enabled: false)
    #expect(DiagLog.isEnabled == false)

    DiagLog.configure(enabled: true)
    #expect(DiagLog.isEnabled == true)
}

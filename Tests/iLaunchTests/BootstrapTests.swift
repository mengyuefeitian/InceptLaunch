import Testing
@testable import iLaunch

@Test func bundleIdentityConstants() {
    #expect(AppIdentity.name == "iLaunch")
    #expect(AppIdentity.bundleIdentifier == "com.ilaunch.iLaunch")
}

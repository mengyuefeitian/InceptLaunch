import Testing
@testable import InceptLaunch

@Test func bundleIdentityConstants() {
    #expect(AppIdentity.name == "InceptLaunch")
    #expect(AppIdentity.bundleIdentifier == "com.inceptlaunch.InceptLaunch")
}

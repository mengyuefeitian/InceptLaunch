import Foundation
import ServiceManagement
import Testing
@testable import InceptLaunch

@Test func registersWhenEnablingAndNotRegistered() {
    #expect(LoginItemService.action(for: true, currentStatus: .notRegistered) == .register)
}

@Test func noopWhenEnablingAndAlreadyEnabled() {
    #expect(LoginItemService.action(for: true, currentStatus: .enabled) == .none)
}

@Test func reregistersWhenRequiresApproval() {
    #expect(LoginItemService.action(for: true, currentStatus: .requiresApproval) == .register)
}

@Test func unregistersWhenDisablingAndEnabled() {
    #expect(LoginItemService.action(for: false, currentStatus: .enabled) == .unregister)
}

@Test func noopWhenDisablingAndNotRegistered() {
    #expect(LoginItemService.action(for: false, currentStatus: .notRegistered) == .none)
}

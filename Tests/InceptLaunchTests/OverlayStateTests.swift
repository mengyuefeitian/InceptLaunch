import Foundation
import Testing
@testable import InceptLaunch

@Test func overlayStateToggle() {
    var state = OverlayState()
    #expect(state.isVisible == false)
    state.toggle()
    #expect(state.isVisible == true)
    state.toggle()
    #expect(state.isVisible == false)
}

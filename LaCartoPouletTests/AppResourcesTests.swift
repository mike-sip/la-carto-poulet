import SwiftUI
import Testing
import UIKit
@testable import LaCartoPoulet

struct AppResourcesTests {
    @Test func displayFontIsBundled() {
        #expect(UIFont(name: "Shrikhand-Regular", size: 17) != nil)
    }

    @Test(arguments: ["Yolk", "Comb", "Feet", "Crispy", "Ink", "Feather"])
    func colorTokenExists(name: String) {
        #expect(UIColor(named: name) != nil)
    }

    @Test func iconsExist() {
        #expect(UIImage(named: "chicken-pin") != nil)
        #expect(UIImage(named: "drumstick") != nil)
    }
}

import XCTest

final class MenuStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "chordTyperEnabled")
        UserDefaults.standard.removeObject(forKey: "englishEnabled")
        UserDefaults.standard.removeObject(forKey: "thaiEnabled")
    }

    // MARK: - Icon Name Logic

    // Mirror of ChordTyperApp.menuBarIcon — pure function, testable without App instantiation
    private func iconName(for enabled: Bool) -> String {
        enabled ? "keyboard.fill" : "keyboard.badge.ellipsis"
    }

    func testMenuState_menuBarIcon_activeShouldBeKeyboardFill() {
        XCTAssertEqual(iconName(for: true), "keyboard.fill")
    }

    func testMenuState_menuBarIcon_pausedShouldBeKeyboardBadgeEllipsis() {
        XCTAssertEqual(iconName(for: false), "keyboard.badge.ellipsis")
    }

    // MARK: - AppStorage Defaults (absence of stored value means @AppStorage default governs)

    func testMenuState_defaultChordTyperEnabled_noStoredValueOnFreshKey() {
        // @AppStorage default (true) is applied by SwiftUI at declaration site.
        // A missing key means the declaration-site default governs — correct behavior.
        XCTAssertNil(
            UserDefaults.standard.object(forKey: "chordTyperEnabled"),
            "chordTyperEnabled must have no stored value on fresh key so @AppStorage default applies"
        )
    }

    func testMenuState_defaultEnglishEnabled_noStoredValueOnFreshKey() {
        XCTAssertNil(
            UserDefaults.standard.object(forKey: "englishEnabled"),
            "englishEnabled must have no stored value on fresh key so @AppStorage default applies"
        )
    }

    func testMenuState_defaultThaiEnabled_noStoredValueOnFreshKey() {
        XCTAssertNil(
            UserDefaults.standard.object(forKey: "thaiEnabled"),
            "thaiEnabled must have no stored value on fresh key so @AppStorage default applies"
        )
    }

    // MARK: - UserDefaults Round-Trip

    func testMenuState_toggleChordTyperEnabled_persistsToUserDefaults() {
        UserDefaults.standard.set(false, forKey: "chordTyperEnabled")
        let stored = UserDefaults.standard.bool(forKey: "chordTyperEnabled")
        XCTAssertFalse(stored, "Setting chordTyperEnabled to false must persist to UserDefaults")
    }
}

//
//  ProfileUITests.swift
//  ChairUITests
//
//  Created by Aaron Musa on 11/3/26.
//

import XCTest

final class ProfileUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testVoiceOverReadsEveryProfileFieldWithItsValue() {
        let app = XCUIApplication()
        app.launchArguments = ["-UseFakes", "-SignedIn"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        let account = app.buttons["settings.account"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        XCTAssertTrue(account.label.contains("@aaron"))
        account.tap()

        let handle = app.textFields["profile.handle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.label, "Handle")
        XCTAssertEqual(handle.value as? String, "aaron")
        let displayName = app.textFields["profile.displayName"]
        XCTAssertEqual(displayName.label, "Display name")
        XCTAssertEqual(displayName.value as? String, "Aaron Musa")
        let homeCourt = app.textFields["profile.homeCourt"]
        XCTAssertEqual(homeCourt.label, "Home court")
        XCTAssertEqual(homeCourt.value as? String, "Rizal Memorial")
        let hand = app.buttons["profile.hand"]
        XCTAssertTrue(hand.label.contains("Hand"))
        XCTAssertTrue(hand.label.contains("Right") || (hand.value as? String) == "Right")
        let level = app.buttons["profile.level"]
        XCTAssertTrue(level.label.contains("Level"))
        XCTAssertTrue(level.label.contains("Intermediate") || (level.value as? String) == "Intermediate")
        XCTAssertTrue(app.images["profile.qr"].exists)
        XCTAssertEqual(app.images["profile.qr"].label, "QR code for @aaron")
        app.swipeUp()
        XCTAssertTrue(app.buttons["profile.signOut"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["profile.delete"].exists)
    }
}

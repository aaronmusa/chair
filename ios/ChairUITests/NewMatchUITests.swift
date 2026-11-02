//
//  NewMatchUITests.swift
//  ChairUITests
//
//  Created by Aaron Musa on 11/2/26.
//

import XCTest

final class NewMatchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testABlankNameShowsAnErrorAndStaysOnNewMatch() {
        let app = launchOnNewMatch()

        app.buttons["newMatch.start"].tap()

        XCTAssertTrue(app.staticTexts["newMatch.error.B1"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["match.session"].exists)
    }

    @MainActor
    func testStartingAValidMatchPresentsTheLiveScreen() {
        let app = launchOnNewMatch()

        let opponent = app.textFields["newMatch.name.B1"]
        opponent.tap()
        opponent.typeText("Juan")
        app.buttons["newMatch.start"].tap()

        XCTAssertTrue(app.staticTexts["match.session"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDoublesShowsFourNamesAndTheTeamPickers() {
        let app = launchOnNewMatch()

        app.buttons["Doubles"].tap()

        for slot in ["A1", "A2", "B1", "B2"] {
            XCTAssertTrue(app.textFields["newMatch.name.\(slot)"].waitForExistence(timeout: 2), "\(slot) row is missing")
        }
        app.swipeUp()
        XCTAssertTrue(app.buttons["newMatch.firstServer.A"].exists || app.otherElements["newMatch.firstServer.A"].exists)
        XCTAssertTrue(app.buttons["newMatch.deuceReceiver.B"].exists || app.otherElements["newMatch.deuceReceiver.B"].exists)
    }

    @MainActor
    private func launchOnNewMatch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UseFakes"]
        app.launch()
        let newMatch = app.buttons["play.newMatch"]
        XCTAssertTrue(newMatch.waitForExistence(timeout: 10))
        newMatch.tap()
        XCTAssertTrue(app.buttons["newMatch.start"].waitForExistence(timeout: 5))
        return app
    }
}

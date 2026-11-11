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
        XCTAssertFalse(app.buttons["getSet.playPoint"].exists)
    }

    @MainActor
    func testStartingAValidMatchPresentsTheLiveScreen() {
        let app = launchOnNewMatch()

        let opponent = app.textFields["newMatch.name.B1"]
        opponent.tap()
        opponent.typeText("Juan")
        app.buttons["newMatch.start"].tap()

        XCTAssertTrue(app.buttons["getSet.playPoint"].waitForExistence(timeout: 5))
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
    func testACameraMatchShowsPlacementBeforeTheLiveScreen() {
        let app = launchOnNewMatch(resettingCamera: true)

        startCameraMatch(in: app)

        XCTAssertTrue(app.buttons["placement.openCamera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Net post"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["getSet.playPoint"].exists)
    }

    @MainActor
    func testDenyingTheCameraPromptShowsTheSettingsLink() {
        let app = launchOnNewMatch(resettingCamera: true)
        startCameraMatch(in: app)
        let openCamera = app.buttons["placement.openCamera"]
        XCTAssertTrue(openCamera.waitForExistence(timeout: 5))

        openCamera.tap()

        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "the system camera prompt should appear")
        alert.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Don'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["camera.status.openSettings"].waitForExistence(timeout: 5))
        XCTAssertFalse(openCamera.exists)
    }

    @MainActor
    private func startCameraMatch(in app: XCUIApplication) {
        let opponent = app.textFields["newMatch.name.B1"]
        opponent.tap()
        opponent.typeText("Juan")
        let form = app.collectionViews.firstMatch
        form.swipeUp()
        form.swipeUp()
        app.buttons["newMatch.input.camera"].tap()
        app.buttons["newMatch.start"].tap()
    }

    @MainActor
    private func launchOnNewMatch(resettingCamera: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if resettingCamera {
            app.resetAuthorizationStatus(for: .camera)
        }
        app.launchArguments = ["-UseFakes"]
        app.launch()
        let newMatch = app.buttons["play.newMatch"]
        XCTAssertTrue(newMatch.waitForExistence(timeout: 10))
        newMatch.tap()
        XCTAssertTrue(app.buttons["newMatch.start"].waitForExistence(timeout: 5))
        return app
    }
}

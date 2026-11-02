//
//  LaunchUITests.swift
//  ChairUITests
//
//  Created by Aaron Musa on 10/26/26.
//

import XCTest

final class LaunchUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsFiveTabsWithPlaySelected() {
        let app = XCUIApplication()
        app.launchArguments = ["-UseFakes"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        for title in ["Play", "Matches", "Train", "Coach", "Settings"] {
            XCTAssertTrue(tabBar.buttons[title].exists, "\(title) tab is missing or not labelled by its name")
        }
        XCTAssertTrue(tabBar.buttons["Play"].isSelected)
    }

    @MainActor
    func testALiveMatchCannotBeSwipedAway() {
        let app = XCUIApplication()
        app.launchArguments = ["-UseFakes", "-PresentSampleMatch"]
        app.launch()

        let session = app.staticTexts["match.session"]
        XCTAssertTrue(session.waitForExistence(timeout: 10))

        session.swipeDown(velocity: .fast)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).tap()

        XCTAssertTrue(session.waitForExistence(timeout: 2))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
    }
}

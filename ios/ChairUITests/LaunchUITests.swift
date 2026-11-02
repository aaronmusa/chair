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

        let session = app.buttons["getSet.playPoint"]
        XCTAssertTrue(session.waitForExistence(timeout: 10))

        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        top.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).tap()

        XCTAssertTrue(session.waitForExistence(timeout: 2))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
    }
}

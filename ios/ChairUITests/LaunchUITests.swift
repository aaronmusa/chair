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
    func testLaunchShowsTheExampleScreen() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Chair"].waitForExistence(timeout: 5))
    }
}

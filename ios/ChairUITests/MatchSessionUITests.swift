//
//  MatchSessionUITests.swift
//  ChairUITests
//
//  Created by Aaron Musa on 11/2/26.
//

import XCTest

final class MatchSessionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAPointForAaronReadsFifteenLoveBackOnGetSet() {
        let app = XCUIApplication()
        app.launchArguments = ["-UseFakes", "-PresentSampleMatch"]
        app.launch()

        let playPoint = app.buttons["getSet.playPoint"]
        XCTAssertTrue(playPoint.waitForExistence(timeout: 10))
        playPoint.tap()

        let pointAaron = app.buttons["session.point.A"]
        XCTAssertTrue(pointAaron.waitForExistence(timeout: 5))
        XCTAssertEqual(pointAaron.label, "Point Aaron")
        XCTAssertEqual(app.buttons["session.point.B"].label, "Point Juan")
        pointAaron.tap()

        let ace = app.buttons["outcome.ace"]
        XCTAssertTrue(ace.waitForExistence(timeout: 5))
        XCTAssertTrue(ace.isEnabled)
        XCTAssertFalse(app.buttons["outcome.doubleFault"].isEnabled)
        app.buttons["outcome.winner"].tap()

        XCTAssertTrue(playPoint.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["getSet.summary"].label.hasSuffix("Fifteen–love"))
    }

    @MainActor
    func testRetiringTheOpponentShowsTheOverlayThenTheSummary() {
        let app = XCUIApplication()
        app.launchArguments = ["-UseFakes", "-PresentSampleMatch"]
        app.launch()

        let pause = app.buttons["session.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10))
        pause.tap()
        let endMatch = app.buttons["pause.endMatch"]
        XCTAssertTrue(endMatch.waitForExistence(timeout: 5))
        endMatch.tap()
        let retire = app.buttons["Retire — Juan"]
        XCTAssertTrue(retire.waitForExistence(timeout: 5))
        retire.tap()

        XCTAssertTrue(app.staticTexts["session.matchOver"].waitForExistence(timeout: 3))
        let header = app.descendants(matching: .any)["summary.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.contains("Aaron def. Juan"))
    }
}

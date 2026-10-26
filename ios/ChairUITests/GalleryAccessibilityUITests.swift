//
//  GalleryAccessibilityUITests.swift
//  ChairUITests
//
//  Created by Aaron Musa on 10/27/26.
//

import XCTest

final class GalleryAccessibilityUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testButtonsReadTheirTitleAndLoadingState() {
        let app = gallery(at: "Buttons")

        XCTAssertTrue(app.buttons["primary · regular"].waitForExistence(timeout: 10))
        let loading = app.buttons["Loading"]
        XCTAssertTrue(loading.exists)
        XCTAssertEqual(loading.value as? String, "Loading")
        XCTAssertFalse(loading.isEnabled)
        XCTAssertFalse(app.buttons["Disabled"].isEnabled)
    }

    @MainActor
    func testPillsReadSelectionAndBadgesAreText() {
        let app = gallery(at: "Pills")

        XCTAssertTrue(app.buttons["Selected"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Selected"].isSelected)
        XCTAssertFalse(app.buttons["Filter"].isSelected)
        XCTAssertTrue(app.staticTexts["Badge"].exists)
        XCTAssertFalse(app.buttons["Badge"].exists)
    }

    @MainActor
    func testSegmentedMarksOnlyTheChosenSegment() {
        let app = gallery(at: "Segmented")

        XCTAssertTrue(app.buttons["Singles"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Singles"].isSelected)
        XCTAssertFalse(app.buttons["Doubles"].isSelected)
    }

    @MainActor
    func testRowsReadTitleAndValue() {
        let app = gallery(at: "Rows")

        let row = app.buttons["Icon, value, chevron"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.value as? String, "Daniel")
        XCTAssertTrue(app.staticTexts["Value only"].exists)
    }

    @MainActor
    func testCardsAndSheetExposeTheirContent() {
        let cards = gallery(at: "Cards")
        XCTAssertTrue(cards.staticTexts["Musa def. Reyes 6–4 7–5"].waitForExistence(timeout: 10))
        cards.terminate()

        let sheet = gallery(at: "Sheet")
        XCTAssertTrue(sheet.staticTexts["Point to Musa?"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testCountdownAndCourtAreReadable() {
        let countdowns = gallery(at: "Countdown ring")
        let ring = countdowns.otherElements["Countdown"].firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 10))
        XCTAssertTrue((ring.value as? String)?.hasSuffix("seconds") == true)
        countdowns.terminate()

        let courts = gallery(at: "Court view")
        XCTAssertTrue(courts.otherElements["Court"].firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    private func gallery(at section: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ShowGallery", "-ReduceMotion", "-GallerySection", section]
        app.launch()
        return app
    }
}

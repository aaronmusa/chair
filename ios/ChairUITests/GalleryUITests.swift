//
//  GalleryUITests.swift
//  ChairUITests
//
//  Created by Aaron Musa on 10/27/26.
//

import XCTest

final class GalleryUITests: XCTestCase {
    private let sections = [
        "Colours", "Type", "Spacing", "Buttons", "Cards", "Pills",
        "Segmented", "Rows", "Sheet", "Countdown ring", "Court view",
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEverySectionIsInTheGallery() {
        for section in sections {
            let app = XCUIApplication()
            app.launchArguments = ["-ShowGallery", "-ReduceMotion", "-GallerySection", section]
            app.launch()

            let header = app.staticTexts["gallery.section.\(section)"]
            XCTAssertTrue(header.waitForExistence(timeout: 30), "\(section) is missing from the gallery")
            XCTAssertTrue(header.isHittable, "\(section) did not scroll on screen")
            app.terminate()
        }
    }

    @MainActor
    func testSettingsOfferAppearanceTextSizeAndReduceMotion() {
        let app = XCUIApplication()
        app.launchArguments = ["-ShowGallery"]
        app.launch()

        let settings = app.buttons["gallery.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        XCTAssertTrue(app.buttons["Dark"].waitForExistence(timeout: 5), "appearance options")
        XCTAssertTrue(app.buttons["AX5"].exists, "text size options")
        XCTAssertTrue(app.switches["Reduce Motion"].exists || app.buttons["Reduce Motion"].exists, "reduce motion toggle")
    }
}

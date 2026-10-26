//
//  ExampleViewModelTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 10/26/26.
//

import XCTest

@testable import Chair

@MainActor
final class ExampleViewModelTests: XCTestCase {
    func testTitleCountsTapsAfterTheFirstTap() {
        let viewModel = ExampleViewModel()
        XCTAssertEqual(viewModel.title, "Chair")

        viewModel.tap()
        viewModel.tap()

        XCTAssertEqual(viewModel.tapCount, 2)
        XCTAssertEqual(viewModel.title, "Tapped 2×")
    }
}

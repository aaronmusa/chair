//
//  ChairUIPackageTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/26/26.
//

import XCTest

import ChairUI

final class ChairUIPackageTests: XCTestCase {
    func testPackageLinksChairKit() {
        XCTAssertEqual(ChairUI.kitName, "ChairKit")
    }
}

//
//  ChairKitTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/26/26.
//

import XCTest

import ChairKit

final class ChairKitTests: XCTestCase {
    func testPackageLinks() {
        XCTAssertEqual(ChairKit.name, "deliberately wrong")
    }
}

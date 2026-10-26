//
//  TestBundleTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import XCTest

import ChairTestSupport

final class TestBundleTests: XCTestCase {
    private struct Court: Decodable, Equatable {
        let name: String
        let surface: String
    }

    func testDecodesAJSONFixtureFromTheTestBundle() throws {
        let court = try TestBundle.decode(Court.self, named: "court", in: .module)

        XCTAssertEqual(court, Court(name: "Centre Court", surface: "hard"))
    }

    func testAMissingFixtureThrowsWithItsName() {
        XCTAssertThrowsError(try TestBundle.data(named: "nowhere.json", in: .module)) { error in
            XCTAssertEqual(error as? TestBundle.FixtureError, .missing("nowhere.json"))
        }
    }
}

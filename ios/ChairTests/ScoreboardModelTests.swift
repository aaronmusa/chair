//
//  ScoreboardModelTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/14/26.
//

import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class ScoreboardModelTests: XCTestCase {
    func testTheHeadlineCallsTheServersScoreFirst() throws {
        let model = try scoreboard(after: [.b, .a, .b])

        XCTAssertTrue(try XCTUnwrap(model.rows.first).isServing)
        XCTAssertEqual(model.headline, "15–30")
    }

    func testDeuceAndAdvantageReadAsNumbers() throws {
        let deuce = try scoreboard(after: [.a, .b, .a, .b, .a, .b])
        XCTAssertEqual(deuce.headline, "40–40")

        let advantage = try scoreboard(after: [.a, .b, .a, .b, .a, .b, .b])
        XCTAssertEqual(advantage.headline, "40–AD")
    }

    func testRowsKeepPlayerAOnTopWhenTheOtherSideServes() throws {
        let model = try scoreboard(after: [.a, .a, .a, .a, .b])

        XCTAssertEqual(model.rows.map(\.side), [.a, .b])
        XCTAssertTrue(try XCTUnwrap(model.rows.last).isServing)
        XCTAssertEqual(model.headline, "15–0")
    }

    private func scoreboard(after winners: [Side]) throws -> ScoreboardModel {
        var log = try MatchLog(rules: MatchRules())
        for (index, side) in winners.enumerated() {
            try log.append(TimedEvent(
                .pointWon(by: side, outcome: nil, ending: nil),
                at: Fixtures.matchDay.addingTimeInterval(Double(index))
            ))
        }
        return ScoreboardModel(state: log.state, names: [.a: "Aaron", .b: "Juan"])
    }
}

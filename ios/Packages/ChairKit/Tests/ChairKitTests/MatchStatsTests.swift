//
//  MatchStatsTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class MatchStatsTests: XCTestCase {
    func testTheSinglesFixtureMatchesTheHandCount() throws {
        let played = try FixtureMatch.play(named: "full_singles_bo3")

        let stats = MatchStats(log: played.log)

        XCTAssertEqual(stats[.a].aces, 6)
        XCTAssertEqual(stats[.b].aces, 6)
        XCTAssertEqual(stats[.a].doubleFaults, 4)
        XCTAssertEqual(stats[.b].doubleFaults, 3)
        XCTAssertEqual(stats[.a].breakPointsFaced, 14)
        XCTAssertEqual(stats[.b].breakPointsFaced, 14)
        XCTAssertEqual(stats[.a].breakPointsWon, 10)
        XCTAssertEqual(stats[.b].breakPointsWon, 11)
        XCTAssertEqual(stats[.a].breakPointChances, stats[.b].breakPointsFaced)
        XCTAssertEqual(stats[.a].breakPointsSaved + stats[.b].breakPointsWon, stats[.a].breakPointsFaced)
        XCTAssertTrue(stats.hasTaggedData)
    }

    func testEveryPointIsCountedOnceWithItsServer() throws {
        let played = try FixtureMatch.play(named: "full_singles_bo3")

        let stats = MatchStats(log: played.log)

        XCTAssertEqual(stats[.a].pointsWon + stats[.b].pointsWon, stats.points.count)
        XCTAssertEqual(stats[.a].servePoints + stats[.b].servePoints, stats.points.count)
        XCTAssertEqual(stats.points.first?.server, .a)
        XCTAssertGreaterThan(stats.longestGame, 4)
        XCTAssertGreaterThan(stats.duration, 0)
    }

    func testOutcomesAreCreditedToTheRightSide() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a, .ace))
        try log.append(point(.b, .unforcedError))
        try log.append(point(.b, .winner))
        try log.append(TimedEvent(.fault, at: Fixtures.matchDay))
        try log.append(point(.a, .forcedError))

        let stats = MatchStats(log: log)

        XCTAssertEqual(stats[.a].aces, 1)
        XCTAssertEqual(stats[.a].unforcedErrors, 1)
        XCTAssertEqual(stats[.b].winners, 1)
        XCTAssertEqual(stats[.b].forcedErrors, 1)
        XCTAssertEqual(stats[.a].servePoints, 4)
        XCTAssertEqual(stats[.a].firstServesIn, 3)
        XCTAssertEqual(stats[.a].firstServePointsWon, 1)
    }

    func testTwoFaultsAreADoubleFaultForTheServer() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(TimedEvent(.fault, at: Fixtures.matchDay))
        try log.append(TimedEvent(.fault, at: Fixtures.matchDay))

        let stats = MatchStats(log: log)

        XCTAssertEqual(stats[.a].doubleFaults, 1)
        XCTAssertEqual(stats[.b].pointsWon, 1)
    }

    func testAMatchWithNoTagsHasOnlyPointsWon() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a, nil))
        try log.append(point(.b, nil))

        let stats = MatchStats(log: log)

        XCTAssertFalse(stats.hasTaggedData)
        XCTAssertEqual(stats[.a].pointsWon, 1)
    }

    private func point(
        _ side: Side,
        _ outcome: PointOutcome?
    ) -> TimedEvent {
        TimedEvent(.pointWon(by: side, outcome: outcome, ending: nil), at: Fixtures.matchDay)
    }
}

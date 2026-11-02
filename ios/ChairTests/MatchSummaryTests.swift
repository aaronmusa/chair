//
//  MatchSummaryTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class MatchSummaryTests: XCTestCase {
    func testWithNoOutcomesOnlyPointsWonHasValues() throws {
        let (match, log) = try SummaryFixture.make(events: [.a, .b, .a].map(SummaryFixture.point))

        let model = MatchSummaryModel(match: match, log: log)

        XCTAssertEqual(model.rows.first, .init(title: "Points won", a: "2", b: "1"))
        XCTAssertTrue(model.rows.dropFirst().allSatisfy { $0.a == "—" && $0.b == "—" })
    }

    func testTaggedPointsFillTheTable() throws {
        let (match, log) = try SummaryFixture.make(events: [
            SummaryFixture.point(.a, .ace),
            SummaryFixture.point(.b, .unforcedError),
        ])

        let model = MatchSummaryModel(match: match, log: log)

        XCTAssertEqual(model.rows.first { $0.title == "Aces" }, .init(title: "Aces", a: "1", b: "0"))
        XCTAssertEqual(model.rows.first { $0.title == "Unforced errors" }, .init(title: "Unforced errors", a: "1", b: "0"))
        XCTAssertEqual(model.points.map(\.detail), ["Ace · Aaron", "Unforced error · Juan"])
        XCTAssertEqual(model.points.first?.context, "Set 1 · Game 1 · Love–Love")
    }

    func testAFinishedMatchReadsTheWinnerAndShares() throws {
        let events = Array(repeating: SummaryFixture.point(.a), count: 48)
        let (match, log) = try SummaryFixture.make(events: events)

        let model = MatchSummaryModel(match: match, log: log)

        XCTAssertEqual(model.result, "Aaron def. Juan")
        XCTAssertEqual(model.setLine, "6–0 6–0")
        XCTAssertEqual(model.shareText, "Aaron def. Juan 6–0 6–0 · Chair")
        XCTAssertEqual(model.runs, [.init(side: .a, length: 48)])
    }

    func testADecidingTiebreakShowsItsPoints() throws {
        var events: [MatchEvent] = []
        for winner in [Side.a, .b] {
            events += Array(repeating: SummaryFixture.point(winner), count: 24)
        }
        for game in 0 ..< 12 {
            events += Array(repeating: SummaryFixture.point(game.isMultiple(of: 2) ? .a : .b), count: 4)
        }
        events += Array(repeating: SummaryFixture.point(.b), count: 7)
        events += Array(repeating: SummaryFixture.point(.a), count: 10)
        let (match, log) = try SummaryFixture.make(events: events, rules: MatchRules(finalSet: .tiebreak10))

        let model = MatchSummaryModel(match: match, log: log)

        XCTAssertEqual(model.shareText, "Aaron def. Juan 6–0 0–6 7–6(10–7) · Chair")
    }

    func testDeletingFromTheSummaryRemovesTheMatch() throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
        let (match, _) = try SummaryFixture.make(events: [SummaryFixture.point(.a)])
        try repository.save(match)
        let viewModel = MatchSessionViewModel(matchID: match.remoteID, repository: repository, clock: FixedClock(Fixtures.matchDay))
        viewModel.load()

        XCTAssertTrue(viewModel.delete())

        XCTAssertTrue(try repository.fetch().isEmpty)
    }
}

enum SummaryFixture {
    static func point(_ side: Side) -> MatchEvent {
        .pointWon(by: side, outcome: nil, ending: nil)
    }

    static func point(
        _ side: Side,
        _ outcome: PointOutcome
    ) -> MatchEvent {
        .pointWon(by: side, outcome: outcome, ending: nil)
    }

    static func make(
        events: [MatchEvent],
        rules: MatchRules = MatchRules()
    ) throws -> (Match, MatchLog) {
        var setup = NewMatchSetup(defaults: MatchDefaults(playerName: "Aaron"))
        setup.rules = rules
        setup.names[.b1] = "Juan"
        let match = try setup.makeMatch(at: Fixtures.matchDay)
        var log = try MatchLog(rules: rules)
        for (index, event) in events.enumerated() {
            try log.append(TimedEvent(event, at: Fixtures.matchDay.addingTimeInterval(Double(index) * 30)))
        }
        match.update(from: log, at: Fixtures.matchDay)
        return (match, log)
    }
}

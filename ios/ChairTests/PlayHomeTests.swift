//
//  PlayHomeTests.swift
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
final class PlayHomeTests: XCTestCase {
    private let now = Fixtures.matchDay.addingTimeInterval(60 * 60)

    func testWithNoMatchesTheTilesAreEmptyAndThereIsNoLastMatch() {
        let model = PlayHomeModel(records: [], now: now)

        XCTAssertNil(model.resume)
        XCTAssertNil(model.lastMatch)
        XCTAssertEqual([model.matchesPlayed, model.firstServe, model.winLoss], ["—", "—", "—"])
    }

    func testAnInProgressMatchShowsTheResumeBanner() throws {
        let (match, _) = try SummaryFixture.make(events: [SummaryFixture.point(.a)])

        let model = PlayHomeModel(records: [match.record], now: now)

        let resume = try XCTUnwrap(model.resume)
        XCTAssertEqual(resume.matchID, match.remoteID)
        XCTAssertEqual(resume.title, "Resume match vs Juan")
        XCTAssertEqual(resume.scoreboard?.headline, "15–0")
        XCTAssertEqual(resume.scoreboard?.rows.map(\.name), ["Aaron", "Juan"])
        XCTAssertNil(model.lastMatch)
    }

    func testThreeMatchesThisWeekWithTwoWinsReadTwoOne() throws {
        let records = try [Side.a, .b, .a].map { winner in
            try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(winner), count: 48)).0.record
        }

        let model = PlayHomeModel(records: records, now: now)

        XCTAssertEqual(model.winLoss, "2–1")
        XCTAssertEqual(model.matchesPlayed, "3")
        XCTAssertNotNil(model.lastMatch)
    }

    func testMatchesOlderThanAWeekAreLeftOutOfTheTiles() throws {
        let (match, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))
        match.playedAt = Fixtures.matchDay.addingTimeInterval(-8 * 24 * 60 * 60)

        let model = PlayHomeModel(records: [match.record], now: now)

        XCTAssertEqual(model.matchesPlayed, "—")
        XCTAssertEqual(model.lastMatch?.matchID, match.remoteID)
    }

    func testFirstServeIsAcrossTheWeeksTaggedMatches() throws {
        let events: [MatchEvent] = [
            .fault,
            SummaryFixture.point(.a, .winner),
            SummaryFixture.point(.a, .ace),
            SummaryFixture.point(.b, .winner),
        ]
        let (match, _) = try SummaryFixture.make(events: events)
        match.status = .completed

        let model = PlayHomeModel(records: [match.record], now: now)

        XCTAssertEqual(model.firstServe, "67%")
    }

    func testResumingRestoresTheLiveScreenAtTheSameScore() throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
        let (match, log) = try SummaryFixture.make(events: [SummaryFixture.point(.a), SummaryFixture.point(.b), SummaryFixture.point(.a)])
        try repository.save(match)

        let home = PlayHomeViewModel(repository: repository, clock: FixedClock(now))
        try home.update(repository.fetch().map(\.record))
        let resume = try XCTUnwrap(home.model.resume)
        let session = MatchSessionViewModel(matchID: resume.matchID, repository: repository, clock: FixedClock(now))
        session.load()

        XCTAssertEqual(session.phase, .getSet)
        XCTAssertEqual(session.state, log.state)
        XCTAssertEqual(session.scoreboard?.rows.map(\.points), ["30", "15"])
    }

    func testTheHomeRefreshesWhenAMatchIsSaved() async throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
        let home = PlayHomeViewModel(repository: repository, clock: FixedClock(now))
        let observing = Task { await home.observe() }
        defer { observing.cancel() }
        for _ in 0 ..< 50 where !home.hasLoaded {
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(50))

        let (match, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))
        try repository.save(match)

        for _ in 0 ..< 50 where home.model.lastMatch == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(home.model.lastMatch?.matchID, match.remoteID)
    }
}

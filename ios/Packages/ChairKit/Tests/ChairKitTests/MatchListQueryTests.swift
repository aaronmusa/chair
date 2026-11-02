//
//  MatchListQueryTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class MatchListQueryTests: XCTestCase {
    func testFiltersKeepOnlyMatchingMatchesNewestFirst() {
        let records = [
            record(format: .singles, opponent: "Juan", daysAgo: 3),
            record(format: .doubles, opponent: "Lia", daysAgo: 1),
            record(format: .doubles, opponent: "Bea", daysAgo: 2, status: .inProgress),
        ]

        XCTAssertEqual(MatchListQuery().apply(records).map(\.opponentNames), ["Lia", "Bea", "Juan"])
        XCTAssertEqual(MatchListQuery(filter: .doubles).apply(records).map(\.opponentNames), ["Lia", "Bea"])
        XCTAssertEqual(MatchListQuery(filter: .singles).apply(records).map(\.opponentNames), ["Juan"])
        XCTAssertEqual(MatchListQuery(filter: .inProgress).apply(records).map(\.opponentNames), ["Bea"])
    }

    func testSearchMatchesTheOpponentIgnoringCase() {
        let records = [record(format: .singles, opponent: "Juan", daysAgo: 1), record(format: .singles, opponent: "Lia", daysAgo: 2)]

        XCTAssertEqual(MatchListQuery(search: " ju ").apply(records).map(\.opponentNames), ["Juan"])
    }

    func testTheRepositoryAppliesTheQueryToEveryEmission() async throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext)
        var iterator = repository.observe(MatchListQuery(filter: .doubles)).makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first?.count, 0)

        try repository.save(match(.singles))
        let second = await iterator.next()
        try repository.save(match(.doubles))
        let third = await iterator.next()

        XCTAssertEqual(second?.count, 0)
        XCTAssertEqual(third?.map(\.format), [.doubles])
    }

    private func match(_ format: MatchFormat) -> Match {
        Match(playedAt: Fixtures.matchDay, format: format, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
    }

    private func record(
        format: MatchFormat,
        opponent: String,
        daysAgo: Double,
        status: MatchStatus = .completed
    ) -> MatchRecord {
        let date = Fixtures.matchDay.addingTimeInterval(-daysAgo * 24 * 60 * 60)
        let match = Match(playedAt: date, format: format, status: status, createdAt: date, updatedAt: date)
        match.players = [
            MatchPlayer(slot: .a1, name: "Aaron", updatedAt: date),
            MatchPlayer(slot: .b1, name: opponent, updatedAt: date),
        ]
        return match.record
    }
}

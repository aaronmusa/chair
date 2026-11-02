//
//  MatchListTests.swift
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
final class MatchListTests: XCTestCase {
    func testMatchesInTwoMonthsShowTwoSectionsNewestFirst() throws {
        let october = try MatchListFixture.record(format: .singles, opponent: "Juan", on: "2026-10-20")
        let september = try MatchListFixture.record(format: .singles, opponent: "Lia", on: "2026-09-12")

        let model = MatchListModel(records: MatchListQuery().apply([september, october]))

        XCTAssertEqual(model.sections.map(\.title), ["October 2026", "September 2026"])
        XCTAssertEqual(model.countLabel, "2 matches")
    }

    func testFilteringDoublesKeepsOnlyDoublesAndUpdatesTheCount() async throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
        for (format, opponent) in [(MatchFormat.singles, "Juan"), (.doubles, "Lia"), (.doubles, "Bea")] {
            try repository.save(MatchListFixture.match(format: format, opponent: opponent, on: "2026-10-20"))
        }
        let viewModel = MatchListViewModel(repository: repository)
        viewModel.query.filter = .doubles

        let observing = Task { await viewModel.observe() }
        defer { observing.cancel() }
        for _ in 0 ..< 50 where !viewModel.hasLoaded {
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(viewModel.model.countLabel, "2 matches")
        XCTAssertEqual(viewModel.records.map(\.format), [.doubles, .doubles])
    }

    func testRowsShowTheResultBadgeAndFooter() throws {
        let (finished, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))
        let (live, _) = try SummaryFixture.make(events: [SummaryFixture.point(.a)])

        let rows = MatchListModel(records: [finished.record, live.record]).sections.flatMap(\.rows)

        XCTAssertEqual(rows.map(\.badge), ["W", "In progress"])
        XCTAssertEqual(rows.first?.footer, "48 points · manual")
        XCTAssertEqual(rows.first?.setLine, "6–0 6–0")
    }

    func testTappingAnInProgressMatchResumesTheSession() {
        let router = AppRouter(selectedSection: .matches)
        let live = UUID()
        let finished = UUID()

        router.openMatch(live, isInProgress: true)
        XCTAssertEqual(router.presentedMatch, PresentedMatch(id: live))
        XCTAssertNil(router.summaryMatchID)

        router.presentedMatch = nil
        router.openMatch(finished, isInProgress: false)
        XCTAssertNil(router.presentedMatch)
        XCTAssertEqual(router.summaryMatchID, finished)
    }
}

enum MatchListFixture {
    static func match(
        format: MatchFormat,
        opponent: String,
        on day: String
    ) throws -> Match {
        let date = try Date(day + "T10:00:00Z", strategy: .iso8601)
        var setup = NewMatchSetup(defaults: MatchDefaults(format: format, playerName: "Aaron"))
        setup.names = [.a1: "Aaron", .a2: "Bea", .b1: opponent, .b2: "Kai"]
        let match = try setup.makeMatch(at: date)
        match.status = .completed
        return match
    }

    static func record(
        format: MatchFormat,
        opponent: String,
        on day: String
    ) throws -> MatchRecord {
        try match(format: format, opponent: opponent, on: day).record
    }
}

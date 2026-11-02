//
//  EndMatchTests.swift
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
final class EndMatchTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: LocalMatchRepository!
    private var matchID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        container = try InMemoryModelContainer()
        repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
        var setup = NewMatchSetup(defaults: MatchDefaults(playerName: "Aaron"))
        setup.names[.b1] = "Juan"
        let match = try setup.makeMatch(at: Fixtures.matchDay)
        try repository.save(match)
        matchID = match.remoteID
    }

    func testOpponentRetiringCompletesTheMatchForAaronWithThePartialSet() async throws {
        let viewModel = makeViewModel()
        for _ in 0 ..< 4 {
            await viewModel.pointWon(by: .a)
        }

        await viewModel.retire(.b)

        XCTAssertEqual(viewModel.phase, .finishing)
        XCTAssertEqual(viewModel.winner, .a)
        let saved = try XCTUnwrap(repository.fetch().first)
        XCTAssertEqual(saved.status, .completed)
        XCTAssertEqual(saved.sets, [SetScore(a: 1, b: 0)])
        viewModel.showSummary()
        XCTAssertEqual(viewModel.phase, .complete)
    }

    func testTheFinalPointEndsTheSessionWithTheOverlay() async throws {
        let viewModel = makeViewModel()
        for _ in 0 ..< 48 {
            await viewModel.pointWon(by: .a)
        }

        XCTAssertEqual(viewModel.phase, .finishing)
        XCTAssertTrue(viewModel.announcementText.hasSuffix("Game, set and match Aaron"))
        XCTAssertEqual(try XCTUnwrap(repository.fetch().first).status, .completed)
    }

    func testFinishAsIsAbandonsTheMatchAndItCannotBeResumed() async throws {
        let viewModel = makeViewModel()
        await viewModel.pointWon(by: .a)

        await viewModel.finishAsIs()

        XCTAssertEqual(viewModel.phase, .complete)
        XCTAssertTrue(viewModel.isAbandoned)
        let saved = try repository.fetch()
        XCTAssertEqual(saved.map(\.status), [.abandoned])
        let reopened = makeViewModel()
        XCTAssertEqual(reopened.phase, .complete)
    }

    private func makeViewModel() -> MatchSessionViewModel {
        let viewModel = MatchSessionViewModel(
            matchID: matchID,
            repository: repository,
            clock: FixedClock(Fixtures.matchDay),
            asksHowPointEnded: false
        )
        viewModel.load()
        return viewModel
    }
}

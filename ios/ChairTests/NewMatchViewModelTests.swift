//
//  NewMatchViewModelTests.swift
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
final class NewMatchViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: LocalMatchRepository!

    override func setUp() async throws {
        try await super.setUp()
        container = try InMemoryModelContainer()
        repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
    }

    func testDoublesShowsFourNameRows() {
        let viewModel = makeViewModel(MatchDefaults(format: .doubles))

        XCTAssertTrue(viewModel.isDoubles)
        XCTAssertEqual(viewModel.setup.slots, [.a1, .a2, .b1, .b2])
        XCTAssertEqual(viewModel.label(for: .b2), "Player B2")
    }

    func testDefaultsArePreselected() {
        let viewModel = makeViewModel(MatchDefaults(format: .doubles, deuce: .noAd, playerName: "Aaron"))

        XCTAssertEqual(viewModel.setup.format, .doubles)
        XCTAssertEqual(viewModel.setup.rules.deuce, .noAd)
        XCTAssertEqual(viewModel.setup.names[.a1], "Aaron")
    }

    func testABlankNameShowsAnErrorAndCreatesNothing() throws {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.error(for: .b1))
        XCTAssertNil(viewModel.start())

        XCTAssertEqual(viewModel.error(for: .b1), "Enter a name")
        XCTAssertNil(viewModel.error(for: .a1))
        XCTAssertTrue(try repository.fetch().isEmpty)
    }

    func testADuplicateNameShowsAnErrorOnBothRows() {
        let viewModel = makeViewModel()
        viewModel.setup.names[.b1] = "you"

        XCTAssertNil(viewModel.start())

        XCTAssertEqual(viewModel.error(for: .a1), "Each player needs a different name")
        XCTAssertEqual(viewModel.error(for: .b1), "Each player needs a different name")
    }

    func testValidInputSavesOneInProgressMatch() throws {
        let viewModel = makeViewModel()
        viewModel.setup.names[.b1] = "Juan"

        let matchID = try XCTUnwrap(viewModel.start())

        let saved = try repository.fetch()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.remoteID, matchID)
        XCTAssertEqual(saved.first?.status, .inProgress)
        XCTAssertEqual(saved.first?.inputModeValue, .manual)
        XCTAssertEqual(saved.first?.orderedPlayers.map(\.name), ["You", "Juan"])
    }

    func testWithoutARepositoryStartShowsAnError() {
        let viewModel = NewMatchViewModel(defaults: MatchDefaults(), repository: nil, clock: FixedClock(Fixtures.matchDay))
        viewModel.setup.names[.b1] = "Juan"

        XCTAssertNil(viewModel.start())
        XCTAssertNotNil(viewModel.startError)
    }

    private func makeViewModel(_ defaults: MatchDefaults = MatchDefaults()) -> NewMatchViewModel {
        NewMatchViewModel(defaults: defaults, repository: repository, clock: FixedClock(Fixtures.matchDay))
    }
}

//
//  AppRouterTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 10/31/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class AppRouterTests: XCTestCase {
    private let matchID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testTheAppStartsOnPlayWithNoSession() throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext)

        let router = AppRouter.make(arguments: [], repository: repository, clock: FixedClock(Fixtures.matchDay))

        XCTAssertEqual(router.selectedSection, .play)
        XCTAssertNil(router.presentedMatch)
        XCTAssertTrue(try repository.fetch().isEmpty)
    }

    func testTheSampleMatchArgumentSavesAMatchAndPresentsIt() throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext)

        let router = AppRouter.make(arguments: ["-PresentSampleMatch"], repository: repository, clock: FixedClock(Fixtures.matchDay))

        let saved = try XCTUnwrap(repository.fetch().first)
        XCTAssertEqual(router.presentedMatch, PresentedMatch(id: saved.remoteID))
        XCTAssertEqual(saved.status, .inProgress)
    }

    func testTheSectionsAreTheFiveInOrder() {
        XCTAssertEqual(AppSection.allCases.map(\.title), ["Play", "Matches", "Train", "Coach", "Settings"])
    }

    func testAMatchLinkOpensThatMatchsSummaryOnMatches() throws {
        let router = AppRouter()
        let url = try XCTUnwrap(URL(string: "chair://match/\(matchID.uuidString)"))

        XCTAssertTrue(router.handle(url))

        XCTAssertEqual(router.selectedSection, .matches)
        XCTAssertEqual(router.summaryMatchID, matchID)
    }

    func testOtherLinksAreIgnored() throws {
        let router = AppRouter()
        let links = [
            "chair://match/not-a-uuid",
            "chair://court/\(matchID.uuidString)",
            "https://match/\(matchID.uuidString)",
            "chair://match",
        ]

        for link in links {
            XCTAssertFalse(try router.handle(XCTUnwrap(URL(string: link))), link)
        }
        XCTAssertEqual(router.selectedSection, .play)
        XCTAssertNil(router.summaryMatchID)
    }

    func testPresentingASessionKeepsItsMatch() {
        let router = AppRouter()

        router.presentSession(for: matchID)

        XCTAssertEqual(router.presentedMatch?.id, matchID)
    }

    func testNewMatchOpensOnPlay() {
        let router = AppRouter(selectedSection: .settings)

        router.showNewMatch()

        XCTAssertEqual(router.selectedSection, .play)
        XCTAssertEqual(router.playPath, [.newMatch])
    }

    func testStartingASessionLeavesNewMatchAndPresentsTheMatch() {
        let router = AppRouter()
        let matchID = UUID()
        router.showNewMatch()

        router.startSession(for: matchID)

        XCTAssertTrue(router.playPath.isEmpty)
        XCTAssertEqual(router.presentedMatch, PresentedMatch(id: matchID))
    }
}

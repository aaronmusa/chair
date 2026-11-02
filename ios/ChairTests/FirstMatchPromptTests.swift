//
//  FirstMatchPromptTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class FirstMatchPromptTests: XCTestCase {
    private var container: ModelContainer?

    func testTheFirstCompletedMatchSignedOutOffersSignInOnceAndNeverAgain() async throws {
        let prompt = FirstMatchPrompt(defaults: freshDefaults())

        let first = try sessionAfterACompletedMatch(auth: FakeAuthService(), prompt: prompt)
        await first.offerSignInAfterFirstMatch()
        XCTAssertTrue(first.isShowingSignInPrompt)

        first.isShowingSignInPrompt = false
        let next = try sessionAfterACompletedMatch(auth: FakeAuthService(), prompt: prompt)
        await next.offerSignInAfterFirstMatch()
        XCTAssertFalse(next.isShowingSignInPrompt)
    }

    func testASignedInPlayerIsNotAsked() async throws {
        let prompt = FirstMatchPrompt(defaults: freshDefaults())
        let session = try sessionAfterACompletedMatch(auth: FakeAuthService(signedIn: true), prompt: prompt)

        await session.offerSignInAfterFirstMatch()

        XCTAssertFalse(session.isShowingSignInPrompt)
        XCTAssertFalse(prompt.wasShown)
    }

    func testAnUnfinishedMatchDoesNotCount() async throws {
        let prompt = FirstMatchPrompt(defaults: freshDefaults())
        let session = try sessionAfterACompletedMatch(auth: FakeAuthService(), prompt: prompt, points: 1)

        await session.offerSignInAfterFirstMatch()

        XCTAssertFalse(session.isShowingSignInPrompt)
        XCTAssertFalse(prompt.wasShown)
    }

    func testUITestsWithFakesOnlyGetThePromptWhenAskedAndStartFresh() {
        XCTAssertNil(FirstMatchPrompt.make(arguments: ["-UseFakes"]))
        XCTAssertEqual(FirstMatchPrompt.make(arguments: ["-UseFakes", "-FirstMatchPrompt"])?.wasShown, false)
        XCTAssertNotNil(FirstMatchPrompt.make(arguments: []))
    }

    private func sessionAfterACompletedMatch(
        auth: FakeAuthService,
        prompt: FirstMatchPrompt,
        points: Int = 48
    ) throws -> MatchSessionViewModel {
        let container = try container ?? InMemoryModelContainer()
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext)
        let (match, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: points))
        try repository.save(match)
        let session = MatchSessionViewModel(
            matchID: match.remoteID,
            repository: repository,
            clock: FixedClock(Fixtures.matchDay),
            auth: auth,
            firstMatchPrompt: prompt
        )
        session.load()
        return session
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "chair.tests.\(UUID().uuidString)") ?? .standard
    }
}

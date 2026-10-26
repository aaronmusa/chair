//
//  FakeServiceTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class FakeServiceTests: XCTestCase {
    func testFakeAuthCanBeSignedInOrOut() async throws {
        let auth = FakeAuthService()
        let signedOut = await auth.currentSession()
        XCTAssertNil(signedOut)

        await auth.setSignedIn(true)
        let signedIn = await auth.currentSession()
        XCTAssertEqual(signedIn, FakeAuthService.sampleSession)

        try await auth.signOut()
        let afterSignOut = await auth.currentSession()
        XCTAssertNil(afterSignOut)
        let calls = await auth.calls
        XCTAssertEqual(calls, ["currentSession", "currentSession", "signOut", "currentSession"])
    }

    func testFakeSpeechOutputRecordsWhatWasSaid() async {
        let speech = FakeSpeechOutput()
        await speech.speak("Fifteen–love")
        await speech.stop()

        let spoken = await speech.spoken
        let stops = await speech.stopCount
        XCTAssertEqual(spoken, ["Fifteen–love"])
        XCTAssertEqual(stops, 1)
    }

    func testFakeSpeechInputPlaysItsScript() async throws {
        let input = FakeSpeechInput(script: [.heard("Chair, undo"), .ended])
        var heard: [SpeechEvent] = []
        for await event in try await input.startListening(grammar: ["undo"]) {
            heard.append(event)
        }

        XCTAssertEqual(heard, [.heard("Chair, undo"), .ended])
        let grammars = await input.grammars
        XCTAssertEqual(grammars, [["undo"]])
    }

    func testFakeCoachReturnsItsCardAndRecordsTheMatch() async throws {
        let coach = FakeCoachService()
        let record = await MainActor.run { Match.sample().record }

        let card = try await coach.summarize(match: record)

        XCTAssertEqual(card, FakeCoachService.sampleCard)
        let summarized = await coach.summarized
        XCTAssertEqual(summarized, [record.id])
    }

    func testFakeSubscriptionStartsATrialOnPurchase() async throws {
        let subscription = FakeSubscriptionService()

        let entitlement = try await subscription.purchase("chair.pro.monthly")

        XCTAssertEqual(entitlement, .trial(expires: Fixtures.matchDay.addingTimeInterval(7 * 24 * 60 * 60)))
        let trial = await subscription.isTrialAvailable()
        XCTAssertFalse(trial)
        do {
            _ = try await subscription.purchase("chair.unknown")
            XCTFail("unknown products should throw")
        } catch {
            XCTAssertEqual(error as? SubscriptionError, .productNotFound("chair.unknown"))
        }
    }

    func testFakeHapticsRecordsEvents() {
        let haptics = FakeHaptics()
        haptics.play(.point)
        haptics.play(.set)

        XCTAssertEqual(haptics.played, [.point, .set])
    }

    func testFakeEnvironmentUsesEveryFake() {
        let environment = AppEnvironment.fakes()

        XCTAssertTrue(environment.auth is FakeAuthService)
        XCTAssertTrue(environment.speechOutput is FakeSpeechOutput)
        XCTAssertTrue(environment.speechInput is FakeSpeechInput)
        XCTAssertTrue(environment.coach is FakeCoachService)
        XCTAssertTrue(environment.subscription is FakeSubscriptionService)
        XCTAssertTrue(environment.clock is FixedClock)
        XCTAssertTrue(environment.haptics is FakeHaptics)
    }
}

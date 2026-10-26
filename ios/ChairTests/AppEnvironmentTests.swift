//
//  AppEnvironmentTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 10/27/26.
//

import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

final class AppEnvironmentTests: XCTestCase {
    private let localInfo: [String: Any] = [
        "SupabaseURL": "http://127.0.0.1:55421",
        "SupabaseAnonKey": "anon-key",
    ]

    func testUseFakesMakesEveryServiceAFake() {
        let environment = AppEnvironment.make(arguments: ["Chair", "-UseFakes"], info: localInfo)

        XCTAssertTrue(environment.auth is FakeAuthService)
        XCTAssertTrue(environment.speechOutput is FakeSpeechOutput)
        XCTAssertTrue(environment.speechInput is FakeSpeechInput)
        XCTAssertTrue(environment.coach is FakeCoachService)
        XCTAssertTrue(environment.subscription is FakeSubscriptionService)
        XCTAssertTrue(environment.clock is FixedClock)
        XCTAssertTrue(environment.haptics is FakeHaptics)
    }

    func testWithSecretsTheAppUsesTheLiveServices() {
        let environment = AppEnvironment.make(arguments: ["Chair"], info: localInfo)

        XCTAssertTrue(environment.auth is SupabaseAuthService)
        XCTAssertTrue(environment.coach is EdgeCoachService)
        XCTAssertTrue(environment.subscription is StoreKitSubscriptionService)
        XCTAssertTrue(environment.speechOutput is SystemSpeechOutput)
        XCTAssertTrue(environment.clock is SystemClock)
    }

    func testWithoutSecretsTheAppFallsBackToUnavailableServices() {
        let unsubstituted: [String: Any] = ["SupabaseURL": "$(SUPABASE_URL)", "SupabaseAnonKey": "$(SUPABASE_ANON_KEY)"]

        let environment = AppEnvironment.make(arguments: ["Chair"], info: unsubstituted)

        XCTAssertTrue(environment.auth is UnavailableService)
        XCTAssertTrue(environment.coach is UnavailableService)
    }
}

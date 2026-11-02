//
//  MatchDefaultsTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class MatchDefaultsTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private let suiteName = "MatchDefaultsTests"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testWithNothingSavedTheDefaultsAreSinglesBestOfThreeWithAdvantage() {
        let defaults = UserDefaultsMatchDefaultsStore(userDefaults: userDefaults).load()

        XCTAssertEqual(defaults, MatchDefaults())
        XCTAssertEqual(defaults.format, .singles)
        XCTAssertEqual(defaults.rules, MatchRules(sets: .bestOf3, deuce: .advantage, finalSet: .tiebreak7))
    }

    func testSavedDefaultsComeBackOnTheNextLoad() {
        let store = UserDefaultsMatchDefaultsStore(userDefaults: userDefaults)
        let saved = MatchDefaults(format: .doubles, sets: .bestOf5, deuce: .noAd, finalSet: .tiebreak10, playerName: "Aaron")

        store.save(saved)

        XCTAssertEqual(UserDefaultsMatchDefaultsStore(userDefaults: userDefaults).load(), saved)
    }

    func testDoublesAndNoAdCarryIntoTheNewMatchRules() {
        let defaults = MatchDefaults(format: .doubles, deuce: .noAd)

        XCTAssertEqual(defaults.format, .doubles)
        XCTAssertEqual(defaults.rules.deuce, .noAd)
    }

    func testWithNoDefaultNamePlayerAIsYou() {
        XCTAssertEqual(MatchDefaults().playerAName, "You")
        XCTAssertEqual(MatchDefaults(playerName: "   ").playerAName, "You")
    }

    func testADefaultNameIsTrimmedForPlayerA() {
        XCTAssertEqual(MatchDefaults(playerName: " Aaron ").playerAName, "Aaron")
    }

    func testUnreadableStoredDataFallsBackToTheDefaults() {
        userDefaults.set(Data("not json".utf8), forKey: UserDefaultsMatchDefaultsStore.key)

        XCTAssertEqual(UserDefaultsMatchDefaultsStore(userDefaults: userDefaults).load(), MatchDefaults())
    }

    func testTheFakeStoreKeepsWhatWasSaved() {
        let store = FakeMatchDefaultsStore()

        store.save(MatchDefaults(format: .doubles))

        XCTAssertEqual(store.load().format, .doubles)
        XCTAssertEqual(store.saves, 1)
    }
}

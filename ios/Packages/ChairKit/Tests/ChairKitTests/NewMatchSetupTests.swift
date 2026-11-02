//
//  NewMatchSetupTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class NewMatchSetupTests: XCTestCase {
    func testItStartsFromTheDefaults() {
        let setup = NewMatchSetup(defaults: MatchDefaults(format: .doubles, deuce: .noAd, playerName: "Aaron"))

        XCTAssertEqual(setup.format, .doubles)
        XCTAssertEqual(setup.rules.deuce, .noAd)
        XCTAssertEqual(setup.names[.a1], "Aaron")
        XCTAssertEqual(setup.slots, [.a1, .a2, .b1, .b2])
    }

    func testWithNoDefaultNamePlayerAIsYou() {
        XCTAssertEqual(NewMatchSetup(defaults: MatchDefaults()).names[.a1], "You")
    }

    func testABlankNameIsAnError() {
        var setup = NewMatchSetup(defaults: MatchDefaults())
        setup.names[.b1] = "  "

        XCTAssertEqual(setup.nameErrors, [.b1: .empty])
        XCTAssertFalse(setup.isValid)
    }

    func testTheSameNameTwiceIsAnErrorOnBothRows() {
        var setup = NewMatchSetup(defaults: MatchDefaults())
        setup.names[.b1] = " you "

        XCTAssertEqual(setup.nameErrors, [.a1: .duplicate, .b1: .duplicate])
    }

    func testSinglesIgnoresTheDoublesRows() {
        var setup = NewMatchSetup(defaults: MatchDefaults())
        setup.names[.b1] = "Juan"

        XCTAssertTrue(setup.isValid)
        XCTAssertEqual(setup.slots, [.a1, .b1])
    }

    func testASinglesMatchIsInProgressManualWithTwoPlayersAndNoEvents() throws {
        var setup = NewMatchSetup(defaults: MatchDefaults(sets: .bestOf5))
        setup.names[.b1] = " Juan "

        let match = try setup.makeMatch(at: Fixtures.matchDay)

        XCTAssertEqual(match.status, .inProgress)
        XCTAssertEqual(match.inputModeValue, .manual)
        XCTAssertEqual(match.rules.sets, .bestOf5)
        XCTAssertEqual(match.orderedPlayers.map(\.name), ["You", "Juan"])
        XCTAssertEqual(match.orderedPlayers.map(\.slot), [.a1, .b1])
        XCTAssertTrue(match.points.isEmpty)
    }

    func testDoublesDefaultsNeedNoPreRallyEvents() throws {
        let match = try doubles().makeMatch(at: Fixtures.matchDay)

        XCTAssertTrue(match.points.isEmpty)
        XCTAssertEqual(match.orderedPlayers.map(\.name), ["You", "Bea", "Juan", "Lia"])
    }

    func testChoosingTheServingTeamsSecondPlayerSendsSwapServer() throws {
        var setup = doubles()
        setup.firstServers[.a] = .a2

        let log = try replay(setup.makeMatch(at: Fixtures.matchDay))

        XCTAssertEqual(log.events.map(\.event), [.swapServer])
        XCTAssertEqual(log.state.server, .a2)
    }

    func testChoosingADeuceReceiverSendsSwapReceivers() throws {
        var setup = doubles()
        setup.deuceReceivers[.b] = .b2

        let log = try replay(setup.makeMatch(at: Fixtures.matchDay))

        XCTAssertEqual(log.events.map(\.event), [.swapReceivers(.b)])
        XCTAssertEqual(log.state.receiver, .b2)
    }

    func testTheReceivingTeamsFirstServerTakesTheFirstSeat() throws {
        var setup = doubles()
        setup.firstServers[.b] = .b2

        let match = try setup.makeMatch(at: Fixtures.matchDay)
        let log = try replay(match)

        XCTAssertEqual(match.orderedPlayers.map(\.name), ["You", "Bea", "Lia", "Juan"])
        XCTAssertEqual(log.events.map(\.event), [.swapReceivers(.b)])
        XCTAssertEqual(log.state.receiver, .b2)
    }

    func testTheReceivingTeamsFirstServerCanAlsoReceiveOnTheDeuceSide() throws {
        var setup = doubles()
        setup.firstServers[.b] = .b2
        setup.deuceReceivers[.b] = .b2

        let match = try setup.makeMatch(at: Fixtures.matchDay)
        let log = try replay(match)

        XCTAssertEqual(match.orderedPlayers.first { $0.slot == .b1 }?.name, "Lia")
        XCTAssertTrue(log.events.isEmpty)
        XCTAssertEqual(log.state.receiver, .b1)
    }

    private func doubles() -> NewMatchSetup {
        var setup = NewMatchSetup(defaults: MatchDefaults(format: .doubles))
        setup.names[.a2] = "Bea"
        setup.names[.b1] = "Juan"
        setup.names[.b2] = "Lia"
        return setup
    }

    private func replay(_ match: Match) throws -> MatchLog {
        try MatchLog(rules: match.rules, format: match.format, pointEvents: match.points)
    }
}

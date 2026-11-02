//
//  WatchSetStartTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class WatchSetStartTests: XCTestCase {
    private struct Subject {
        let model: WatchMatchModel
        let session: FakeWCSession
    }

    func testAServingTeamPicksItsServerThenItsDeuceReceiver() async {
        let subject = makeSubject(server: .a1)

        XCTAssertEqual(subject.model.setStartCard, .serve(first: .a1, second: .a2))
        await subject.model.chooseServer(second: true)
        XCTAssertEqual(subject.model.setStartCard, .deuce(current: .a1, partner: .a2))
        await subject.model.chooseDeuceReceiver(partner: false)

        XCTAssertNil(subject.model.setStartCard)
        XCTAssertEqual(subject.session.sent.compactMap(\.action), [.swapServer])
    }

    func testAReceivingTeamOnlyPicksItsDeuceReceiver() async {
        let subject = makeSubject(server: .b1)

        XCTAssertEqual(subject.model.setStartCard, .deuce(current: .a1, partner: .a2))
        await subject.model.chooseDeuceReceiver(partner: true)

        XCTAssertNil(subject.model.setStartCard)
        XCTAssertEqual(subject.session.sent.compactMap(\.action), [.swapReceivers(.a)])
    }

    func testTheCardsGoAwayOnceTheSetHasStarted() {
        let subject = makeSubject(server: .a1)
        var state = Self.doublesState(server: .a1)
        state.score.currentGame = .standard(a: .fifteen, b: .love)

        subject.model.apply(.state(state))

        XCTAssertNil(subject.model.setStartCard)
    }

    func testSinglesNeverAsks() {
        let model = WatchMatchModel(link: WatchLink(transport: FakeWCSession()))
        var state = WatchMessageTests.sampleState
        state.score = ScoreSnapshot(sets: [], currentSet: SetScore(a: 0, b: 0), currentGame: .loveAll, server: .a1)
        state.phase = .getSet

        model.apply(.state(state))

        XCTAssertNil(model.setStartCard)
    }

    func testTheResultReadsFromTheUsersSide() {
        var state = WatchMessageTests.sampleState
        state.phase = .complete
        state.score.sets = [SetScore(a: 6, b: 4), SetScore(a: 3, b: 6), SetScore(a: 7, b: 6)]
        state.score.currentSet = SetScore(a: 0, b: 0)
        state.winner = .a
        XCTAssertEqual(state.resultText, "You won 6–4 3–6 7–6")

        state.mySlot = .b1
        XCTAssertEqual(state.resultText, "You lost 4–6 6–3 6–7")

        state.winner = nil
        state.score.currentSet = SetScore(a: 2, b: 1)
        XCTAssertEqual(state.resultText, "Match ended 4–6 6–3 6–7 1–2")
    }

    func testEndMatchSendsTheChoice() async {
        let subject = makeSubject(server: .a1)

        await subject.model.endMatch(.retireThem)

        XCTAssertEqual(subject.session.sent.compactMap(\.action), [.endMatch(.retireThem)])
    }

    private func makeSubject(server: PlayerSlot) -> Subject {
        let session = FakeWCSession()
        let model = WatchMatchModel(link: WatchLink(transport: session))
        model.apply(.state(Self.doublesState(server: server)))
        return Subject(model: model, session: session)
    }

    static func doublesState(server: PlayerSlot) -> WatchState {
        WatchState(
            matchID: WatchMessageTests.sampleState.matchID,
            names: [.a1: "Aaron", .a2: "Ana", .b1: "Ben", .b2: "Cy"],
            mySlot: .a1,
            score: ScoreSnapshot(sets: [SetScore(a: 6, b: 4)], currentSet: SetScore(a: 0, b: 0), currentGame: .loveAll, server: server),
            serverCourtSide: .deuce,
            serve: .first,
            phase: .getSet,
            deuceReceiver: .a1
        )
    }
}

private extension WatchMessage {
    var action: WatchInput.Action? {
        guard case let .input(input) = self else { return nil }
        return input.action
    }
}

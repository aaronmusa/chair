//
//  WatchHomeTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class WatchHomeTests: XCTestCase {
    func testAnInProgressMatchOffersJoinWithTheDeliveredScore() {
        let model = makeModel(reachable: true)

        model.apply(.state(WatchMessageTests.sampleState))

        XCTAssertEqual(model.home, .join(WatchMessageTests.sampleState))
        XCTAssertEqual(WatchMessageTests.sampleState.title, "Aaron v Juan")
        XCTAssertEqual(WatchMessageTests.sampleState.setsLine, "2–1")
        XCTAssertEqual(WatchMessageTests.sampleState.pointsLine, "30–15")
    }

    func testNoMatchAsksToStartOnThePhoneWithTheLastResult() {
        let model = makeModel(reachable: true)
        model.apply(.state(WatchMessageTests.sampleState))

        model.apply(.idle(lastResult: "vs Juan · 6–4 6–3"))

        XCTAssertEqual(model.home, .startOnPhone(lastResult: "vs Juan · 6–4 6–3"))
    }

    func testAnUnreachablePhoneWithNoMatchSaysToOpenChair() {
        XCTAssertEqual(makeModel(reachable: false).home, .unreachable)
    }

    func testTheScoreReadsFromTheUsersSide() {
        var state = WatchMessageTests.sampleState
        state.mySide = .b
        state.score.sets = [SetScore(a: 6, b: 4)]
        state.score.currentGame = .tiebreak(a: 5, b: 3, target: 7)
        state.names = [.a1: "Juan", .a2: "Ana", .b1: "Aaron", .b2: "Ben"]

        XCTAssertEqual(state.title, "Aaron + Ben v Juan + Ana")
        XCTAssertEqual(state.setsLine, "4–6 1–2")
        XCTAssertEqual(state.pointsLine, "3–5")
    }

    func testNewMatchIsQueuedForThePhone() {
        let session = FakeWCSession()
        let model = WatchMatchModel(link: WatchLink(transport: session))

        model.openNewMatchOnPhone()

        XCTAssertEqual(session.transferredUserInfo, [.openNewMatch])
    }

    private func makeModel(reachable: Bool) -> WatchMatchModel {
        let link = WatchLink(transport: FakeWCSession(reachable: reachable))
        link.activate()
        return WatchMatchModel(link: link)
    }
}

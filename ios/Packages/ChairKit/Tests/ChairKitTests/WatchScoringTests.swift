//
//  WatchScoringTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class WatchScoringTests: XCTestCase {
    private final class HapticsSpy: WatchHaptics {
        private(set) var played: [WatchHaptic] = []

        func play(_ haptic: WatchHaptic) {
            played.append(haptic)
        }
    }

    private struct Subject {
        let model: WatchMatchModel
        let session: FakeWCSession
        let haptics: HapticsSpy
    }

    func testATouchShorterThanTheHoldSendsNothing() async throws {
        let subject = makeSubject()
        let gate = HoldGate()

        gate.begin(onFire: handleScore(subject.model))
        try await Task.sleep(for: .milliseconds(200))
        gate.end()
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(subject.session.sent.isEmpty)
        XCTAssertTrue(subject.haptics.played.isEmpty)
    }

    func testAFullHoldOnMeSendsThePointAndClicks() async throws {
        let subject = makeSubject()
        let gate = HoldGate()

        gate.begin(onFire: handleScore(subject.model))
        try await Task.sleep(for: .milliseconds(450))
        gate.end()
        try await Task.sleep(for: .milliseconds(50))

        guard case let .input(input) = subject.session.sent.first else {
            return XCTFail("expected an input")
        }
        XCTAssertEqual(input.action, .point(.a))
        XCTAssertEqual(input.matchID, WatchMessageTests.sampleState.matchID)
        XCTAssertEqual(subject.haptics.played, [.click])
    }

    func testHoldingPastTheThresholdFiresOnce() async throws {
        let subject = makeSubject()
        let gate = HoldGate(duration: .milliseconds(50))

        gate.begin(onFire: handleScore(subject.model))
        try await Task.sleep(for: .milliseconds(100))
        gate.begin(onFire: handleScore(subject.model))
        try await Task.sleep(for: .milliseconds(100))
        gate.end()

        XCTAssertEqual(subject.session.sent.count, 1)
    }

    func testMeIsTheUsersOwnSide() async {
        let subject = makeSubject()
        var state = WatchMessageTests.sampleState
        state.mySlot = .b1
        subject.model.apply(.state(state))

        await subject.model.score(me: true)
        await subject.model.score(me: false)

        XCTAssertEqual(subject.session.sent.compactMap(\.inputAction), [.point(.b), .point(.a)])
    }

    func testUndoShowsCorrectionAfterTheAck() async {
        let subject = makeSubject()

        await subject.model.send(.undo)
        XCTAssertFalse(subject.model.showsCorrection)
        guard case let .input(input) = subject.session.sent.first else {
            return XCTFail("expected an input")
        }
        subject.model.apply(.ack(inputID: input.id))

        XCTAssertTrue(subject.model.showsCorrection)

        await subject.model.send(.fault)
        XCTAssertFalse(subject.model.showsCorrection)
    }

    func testEachAnnouncementIsShownAfresh() {
        let subject = makeSubject()

        subject.model.apply(.announcement(text: "Double fault"))
        subject.model.apply(.announcement(text: "Double fault"))

        XCTAssertEqual(subject.model.announcement, "Double fault")
        XCTAssertEqual(subject.model.announcementID, 2)
    }

    func testTheScoreScreenText() {
        var state = WatchMessageTests.sampleState
        XCTAssertEqual(state.setGameLabel, "Set 1 · Game 4")
        XCTAssertEqual(state.serveStrip, "You serve · ad")
        XCTAssertEqual(state.rowName(for: .a), "You")
        XCTAssertEqual(state.rowName(for: .b), "Juan")
        XCTAssertEqual(state.games(for: .a), [2])

        state.names = [.a1: "Aaron", .a2: "Ana", .b1: "Benedikta", .b2: "Cy"]
        state.score.server = .b1
        state.serve = .second
        state.score.currentGame = .tiebreak(a: 1, b: 0, target: 7)

        XCTAssertEqual(state.rowName(for: .a), "You + Ana")
        XCTAssertEqual(state.rowName(for: .b), "Benedikt + Cy")
        XCTAssertEqual(state.serveStrip, "Benedikt serves · ad · 2nd serve")
        XCTAssertEqual(state.setGameLabel, "Set 1 · Tiebreak")
    }

    private func makeSubject() -> Subject {
        let session = FakeWCSession()
        let haptics = HapticsSpy()
        let model = WatchMatchModel(link: WatchLink(transport: session), haptics: haptics)
        model.apply(.state(WatchMessageTests.sampleState))
        return Subject(model: model, session: session, haptics: haptics)
    }

    private func handleScore(_ model: WatchMatchModel) -> () -> Void {
        { [weak model] in Task { await model?.score(me: true) } }
    }
}

private extension WatchMessage {
    var inputAction: WatchInput.Action? {
        guard case let .input(input) = self else { return nil }
        return input.action
    }
}

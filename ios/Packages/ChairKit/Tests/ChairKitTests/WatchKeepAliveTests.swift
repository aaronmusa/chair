//
//  WatchKeepAliveTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class WatchKeepAliveTests: XCTestCase {
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
        let keepAlive: NoKeepAlive
    }

    func testJoiningStartsTheWorkoutAndTheMatchEndingStopsIt() async {
        let subject = makeSubject()

        await subject.model.join()
        XCTAssertTrue(subject.keepAlive.isRunning)
        XCTAssertEqual(subject.session.sent, [.requestState])

        subject.model.apply(.matchEnded)

        XCTAssertFalse(subject.keepAlive.isRunning)
    }

    func testACompleteStateEndsTheWorkoutWhenTheEndMessageWasMissed() async {
        let subject = makeSubject()
        await subject.model.join()
        var finished = WatchMessageTests.sampleState
        finished.phase = .complete

        subject.model.apply(.state(finished))

        XCTAssertFalse(subject.keepAlive.isRunning)
    }

    func testEndingTheWorkoutFromTheWatchTellsThePhone() async {
        let subject = makeSubject()
        await subject.model.join()

        await subject.model.endWorkout()

        XCTAssertFalse(subject.keepAlive.isRunning)
        XCTAssertEqual(subject.session.sent.last, .endWorkout)
    }

    func testAGameAndASetPlayTheirHaptics() {
        let subject = makeSubject()
        var state = WatchMessageTests.sampleState
        subject.model.apply(.state(state))

        state.score.currentSet = SetScore(a: 3, b: 1)
        subject.model.apply(.state(state))
        state.score.sets = [SetScore(a: 6, b: 4)]
        state.score.currentSet = SetScore(a: 0, b: 0)
        subject.model.apply(.state(state))
        state.score.currentGame = .standard(a: .fifteen, b: .love)
        subject.model.apply(.state(state))

        XCTAssertEqual(subject.haptics.played, [.notification, .success])
    }

    func testARefusedInputPlaysTheFailureHapticAndClearsThePending() async throws {
        let subject = makeSubject()
        subject.model.link.activate()
        await subject.model.send(.swapEnds)
        guard case let .input(input) = subject.session.sent.last else {
            return XCTFail("expected an input")
        }

        subject.session.receive(.refused(inputID: input.id))
        for _ in 0 ..< 50 where subject.model.link.pendingInputCount > 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        subject.model.apply(.refused(inputID: input.id))

        XCTAssertEqual(subject.model.link.pendingInputCount, 0)
        XCTAssertEqual(subject.haptics.played, [.click, .failure])
    }

    private func makeSubject() -> Subject {
        let session = FakeWCSession()
        let haptics = HapticsSpy()
        let keepAlive = NoKeepAlive()
        let model = WatchMatchModel(link: WatchLink(transport: session), haptics: haptics, keepAlive: keepAlive)
        model.apply(.state(WatchMessageTests.sampleState))
        return Subject(model: model, session: session, haptics: haptics, keepAlive: keepAlive)
    }
}

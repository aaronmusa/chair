//
//  WatchInputGateTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class WatchInputGateTests: XCTestCase {
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

    func testATapOnMeScoresAndClicksByDefault() async {
        let subject = makeSubject(awake: true)

        await subject.model.score(me: true)

        XCTAssertEqual(subject.session.sent.compactMap(\.action), [.point(.a)])
        XCTAssertEqual(subject.haptics.played, [.click])
    }

    func testADimmedWatchIgnoresTapsAndTheCrown() async throws {
        let subject = makeSubject(awake: false)

        await subject.model.score(me: true)
        subject.model.turnCrown(up: true)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(subject.session.sent.isEmpty)
        XCTAssertTrue(subject.haptics.played.isEmpty)
    }

    func testTheScreenMustBeLitForThreeHundredMilliseconds() {
        let gate = InputGate()
        let woke = ContinuousClock.now

        gate.update(isLuminanceReduced: false, at: woke)

        XCTAssertFalse(gate.allows(at: woke + .milliseconds(200)))
        XCTAssertTrue(gate.allows(at: woke + .milliseconds(300)))
        gate.update(isLuminanceReduced: true, at: woke + .milliseconds(400))
        XCTAssertFalse(gate.allows(at: woke + .seconds(5)))
    }

    func testOneCrownDetentUpScoresMeAfterTheWindow() async throws {
        let subject = makeSubject(awake: true)

        subject.model.turnCrown(up: true)
        XCTAssertEqual(subject.model.crown.pendingMe, true)
        XCTAssertEqual(subject.haptics.played, [.click])
        XCTAssertTrue(subject.session.sent.isEmpty)
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(subject.session.sent.compactMap(\.action), [.point(.a)])
        XCTAssertNil(subject.model.crown.pendingMe)
        XCTAssertEqual(subject.haptics.played, [.click])
    }

    func testTurningBackWithinTheWindowCancels() async throws {
        let subject = makeSubject(awake: true)

        subject.model.turnCrown(up: true)
        subject.model.turnCrown(up: false)
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(subject.session.sent.isEmpty)
        XCTAssertNil(subject.model.crown.pendingMe)
    }

    func testALongSpinSendsOnePoint() async throws {
        let subject = makeSubject(awake: true)

        for _ in 0 ..< 5 {
            subject.model.turnCrown(up: true)
        }
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(subject.session.sent.compactMap(\.action), [.point(.a)])
    }

    func testCrownDownScoresThem() async throws {
        let subject = makeSubject(awake: true)

        subject.model.turnCrown(up: false)
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(subject.session.sent.compactMap(\.action), [.point(.b)])
    }

    func testTheConfirmWindowIsOneSecond() {
        XCTAssertEqual(CrownScorer.confirmWindow, .seconds(1))
        XCTAssertEqual(InputGate.settleTime, .milliseconds(300))
    }

    private func makeSubject(awake: Bool) -> Subject {
        let session = FakeWCSession()
        let haptics = HapticsSpy()
        let model = WatchMatchModel(
            link: WatchLink(transport: session),
            haptics: haptics,
            crown: CrownScorer(window: .milliseconds(100))
        )
        model.apply(.state(WatchMessageTests.sampleState))
        model.gate.update(isLuminanceReduced: !awake, at: .now - .seconds(1))
        return Subject(model: model, session: session, haptics: haptics)
    }
}

private extension WatchMessage {
    var action: WatchInput.Action? {
        guard case let .input(input) = self else { return nil }
        return input.action
    }
}

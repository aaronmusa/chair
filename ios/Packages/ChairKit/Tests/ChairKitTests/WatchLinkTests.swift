//
//  WatchLinkTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class WatchLinkTests: XCTestCase {
    private struct Pair {
        let phone: WatchLink
        let watch: WatchLink
        let watchSession: FakeWCSession
        let received: StreamCollector<WatchInput>
    }

    func testInputsSentWhileUnreachableArriveOnceInOrderWhenThePhoneReturns() async throws {
        let pair = makePair(reachable: false)
        let inputs = [WatchInput(.point(.a)), WatchInput(.fault), WatchInput(.point(.b)), WatchInput(.let), WatchInput(.undo)]

        for input in inputs {
            await pair.watch.send(input)
        }

        XCTAssertEqual(pair.watchSession.transferredUserInfo, inputs.map { .input($0) })
        XCTAssertEqual(pair.watch.pendingInputCount, 5)
        let early = await pair.received.value(after: .milliseconds(50))
        XCTAssertTrue(early.isEmpty)

        pair.watchSession.setReachable(true)

        try await waitUntil { pair.watch.pendingInputCount == 0 }
        let arrived = await pair.received.value(count: inputs.count)
        XCTAssertEqual(arrived.map(\.id), inputs.map(\.id))
    }

    func testAnInputDeliveredTwiceIsAppliedOnceAndAckedBothTimes() async {
        let session = FakeWCSession()
        let phone = WatchLink(transport: session)
        phone.activate()
        let received = StreamCollector(phone.inputs)
        let input = WatchInput(.point(.b))

        session.receive(.input(input))
        session.receive(.input(input))
        _ = await received.value(count: 1)
        let applied = await received.value(after: .milliseconds(100))
        await phone.acknowledge(input.id)

        XCTAssertEqual(applied, [input])
        XCTAssertEqual(session.sent, [.ack(inputID: input.id), .ack(inputID: input.id)])
    }

    func testTheLastHundredAppliedIDsAreRemembered() async {
        let session = FakeWCSession()
        let phone = WatchLink(transport: session)
        phone.activate()
        let received = StreamCollector(phone.inputs)
        let first = WatchInput(.fault)

        session.receive(.input(first))
        for _ in 0 ..< WatchLink.appliedIDLimit {
            session.receive(.input(WatchInput(.let)))
        }
        session.receive(.input(first))

        let applied = await received.value(count: WatchLink.appliedIDLimit + 2)
        XCTAssertEqual(applied.count, WatchLink.appliedIDLimit + 2)
        XCTAssertEqual(applied.last, first)
    }

    func testAProtocolMismatchStopsTheWatchSending() async throws {
        let session = FakeWCSession()
        let watch = WatchLink(transport: session)
        watch.activate()

        session.receive(raw: Data(#"{"protocolVersion":2,"message":null}"#.utf8))
        try await waitUntil { watch.isVersionMismatched }
        await watch.send(WatchInput(.point(.a)))
        await watch.send(.requestState)

        XCTAssertTrue(session.sent.isEmpty)
        XCTAssertEqual(watch.pendingInputCount, 0)
    }

    func testUnackedInputsAreResentThenHeldAsWaiting() async throws {
        let session = FakeWCSession()
        let watch = WatchLink(transport: session, retryInterval: .milliseconds(20), retryLimit: .milliseconds(100))
        watch.activate()
        let input = WatchInput(.undo)

        await watch.send(input)

        try await waitUntil { session.sent.count >= 3 }
        try await waitUntil { watch.isWaitingForPeer }
        XCTAssertEqual(watch.pendingInputCount, 1)
        XCTAssertTrue(session.sent.allSatisfy { $0 == .input(input) })

        session.receive(.ack(inputID: input.id))

        try await waitUntil { watch.pendingInputCount == 0 }
        XCTAssertFalse(watch.isWaitingForPeer)
        XCTAssertNotNil(watch.lastAckLatency)
    }

    func testReachabilityChangesAreStreamed() async {
        let session = FakeWCSession(reachable: false)
        let link = WatchLink(transport: session)
        link.activate()
        let changes = StreamCollector(link.reachabilityStream)

        session.setReachable(true)
        session.setReachable(false)

        let seen = await changes.value(count: 2)
        XCTAssertEqual(seen, [true, false])
        XCTAssertFalse(link.isReachable)
    }

    func testTheSameStateTwiceDoesNotRedraw() {
        let model = WatchMatchModel(link: WatchLink(transport: FakeWCSession()))
        model.apply(.state(WatchMessageTests.sampleState))
        let redraws = RedrawCounter()
        withObservationTracking {
            _ = model.state
        } onChange: {
            redraws.increment()
        }

        model.apply(.state(WatchMessageTests.sampleState))

        XCTAssertEqual(redraws.count, 0)
        var next = WatchMessageTests.sampleState
        next.score.currentGame = .standard(a: .forty, b: .fifteen)
        model.apply(.state(next))
        XCTAssertEqual(redraws.count, 1)
    }

    func testACompleteStateEndsTheMatchOnTheWatch() {
        let model = WatchMatchModel(link: WatchLink(transport: FakeWCSession()))
        var finished = WatchMessageTests.sampleState
        finished.phase = .complete

        model.apply(.state(finished))

        XCTAssertTrue(model.hasEnded)
    }

    private func makePair(reachable: Bool) -> Pair {
        let sessions = FakeWCSession.pair(reachable: reachable)
        let phone = WatchLink(transport: sessions.phone)
        let watch = WatchLink(transport: sessions.watch)
        phone.activate()
        watch.activate()
        let received = StreamCollector(phone.inputs, onEach: handleAck(on: phone))
        return Pair(phone: phone, watch: watch, watchSession: sessions.watch, received: received)
    }

    private func handleAck(on link: WatchLink) -> @MainActor (WatchInput) async -> Void {
        { [weak link] input in await link?.acknowledge(input.id) }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0 ..< 100 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition())
    }
}

private final class RedrawCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.withLock { value }
    }

    func increment() {
        lock.withLock { value += 1 }
    }
}

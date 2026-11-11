//
//  CaptureTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreVideo
import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class CaptureTests: XCTestCase {
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var frames = 0
        private var onMain = 0
        private var rates: [Int] = []
        private var sizes: Set<[Int]> = []

        var frameCount: Int {
            lock.withLock { frames }
        }

        var mainThreadCalls: Int {
            lock.withLock { onMain }
        }

        var frameRates: [Int] {
            lock.withLock { rates }
        }

        var frameSizes: Set<[Int]> {
            lock.withLock { sizes }
        }

        func record(_ frame: Frame) {
            let size = [CVPixelBufferGetWidth(frame.pixelBuffer), CVPixelBufferGetHeight(frame.pixelBuffer)]
            let main = Thread.isMainThread
            lock.withLock {
                frames += 1
                onMain += main ? 1 : 0
                sizes.insert(size)
            }
        }

        func record(rate: Int) {
            lock.withLock { rates.append(rate) }
        }
    }

    func testASlowConsumerIsThrottledWhileAFastOneKeepsSixty() async throws {
        let capture = FakeCaptureSession(source: .blank(width: 1920, height: 1080))
        let slow = Recorder()
        let fast = Recorder()
        capture.fanOut.register(label: "slow", maxRate: 60, onFrame: { frame in
            slow.record(frame)
            Thread.sleep(forTimeInterval: 0.1)
        })
        capture.fanOut.register(label: "fast", priority: 1, maxRate: 60, onFrame: { fast.record($0) })

        await capture.start()
        try await Task.sleep(for: .seconds(2))
        await capture.stop()

        XCTAssertEqual(Double(slow.frameCount) / 2, 10, accuracy: 3)
        XCTAssertGreaterThan(Double(fast.frameCount) / 2, 50)
        XCTAssertEqual(slow.mainThreadCalls + fast.mainThreadCalls, 0)
    }

    func testAConsumerNeverReceivesMoreThanItsMaxRate() async throws {
        let capture = FakeCaptureSession(source: .blank(width: 640, height: 360))
        let quarter = Recorder()
        capture.fanOut.register(label: "quarter", maxRate: 15, onFrame: { quarter.record($0) })

        await capture.start()
        try await Task.sleep(for: .seconds(2))
        await capture.stop()

        XCTAssertEqual(Double(quarter.frameCount) / 2, 15, accuracy: 3)
    }

    func testSeriousHeatDropsToThirtyAndTellsConsumersThenCriticalPauses() async throws {
        let capture = FakeCaptureSession(source: .blank(width: 640, height: 360))
        let consumer = Recorder()
        capture.fanOut.register(
            label: "rates",
            maxRate: 60,
            onFrame: { consumer.record($0) },
            onFrameRate: { consumer.record(rate: $0) }
        )
        await capture.start()
        XCTAssertEqual(capture.state, .running(frameRate: 60))

        capture.simulateThermal(.serious)
        XCTAssertEqual(capture.state, .running(frameRate: 30))
        XCTAssertEqual(capture.fanOut.frameRate, 30)
        let before = capture.framesSent
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(Double(capture.framesSent - before), 30, accuracy: 6)

        capture.simulateThermal(.critical)
        XCTAssertEqual(capture.state, .pausedForHeat)
        let paused = capture.framesSent
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(capture.framesSent, paused)

        capture.simulateThermal(.nominal)
        XCTAssertEqual(capture.state, .running(frameRate: 60))
        await capture.stop()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(consumer.frameRates, [30, 60])
    }

    func testAnInterruptionStopsFramesUntilItEnds() async throws {
        let capture = FakeCaptureSession(source: .blank(width: 640, height: 360))
        await capture.start()

        capture.simulateInterruption(.otherApp)
        XCTAssertEqual(capture.state, .interrupted(.otherApp))
        let held = capture.framesSent
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(capture.framesSent, held)

        capture.endInterruption()
        XCTAssertEqual(capture.state, .running(frameRate: 60))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertGreaterThan(capture.framesSent, held)
        await capture.stop()
    }

    func testDeniedPermissionMakesTheCameraUnavailable() async {
        let denied = FakeCaptureSession(source: .blank(width: 640, height: 360), authorization: FakeCameraAuthorization(.denied))
        var states = denied.states().makeAsyncIterator()
        _ = await states.next()

        await denied.start()

        XCTAssertEqual(denied.state, .unavailable(.permissionDenied))
        let next = await states.next()
        XCTAssertEqual(next, .unavailable(.permissionDenied))
        XCTAssertEqual(denied.framesSent, 0)
    }

    func testTheFakeReplaysAFootageClipAndLoopsAtTheChosenRate() async throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Footage", withExtension: nil, subdirectory: "Fixtures"))
        let capture = FakeCaptureSession(source: .clip(folder.appending(path: "synthetic-netPost.mp4")), rate: 240)
        let consumer = Recorder()
        capture.fanOut.register(label: "clip", maxRate: 240, onFrame: { consumer.record($0) })

        await capture.start()
        try await Task.sleep(for: .seconds(1))
        await capture.stop()

        XCTAssertGreaterThan(capture.framesSent, 120, "the 2 s clip has 120 frames, so it looped")
        XCTAssertEqual(consumer.frameSizes, [[1920, 1080]])
    }

    func testTheThermalPolicy() {
        XCTAssertEqual(ThermalPolicy.frameRate(for: .nominal, preferred: 60), 60)
        XCTAssertEqual(ThermalPolicy.frameRate(for: .fair, preferred: 60), 60)
        XCTAssertEqual(ThermalPolicy.frameRate(for: .serious, preferred: 60), 30)
        XCTAssertEqual(ThermalPolicy.frameRate(for: .serious, preferred: 24), 24)
        XCTAssertNil(ThermalPolicy.frameRate(for: .critical, preferred: 60))
    }
}

//
//  CountdownTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI
import XCTest

@testable import ChairUI

final class CountdownTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_793_000_000)

    func testReduceMotionStepsOncePerSecond() {
        let countdown = Countdown(startedAt: start, duration: 5)

        let states = [0, 0.4, 0.99, 1, 1.7, 2.2].map { countdown.state(at: start.addingTimeInterval($0), stepped: true) }

        XCTAssertEqual(states.map(\.progress), [0, 0, 0, 0.2, 0.2, 0.4])
        XCTAssertEqual(states.map(\.secondsLeft), [5, 5, 5, 4, 4, 3])
    }

    func testWithoutReduceMotionProgressIsContinuous() {
        let countdown = Countdown(startedAt: start, duration: 5)

        XCTAssertEqual(countdown.state(at: start.addingTimeInterval(1.5), stepped: false).progress, 0.3, accuracy: 0.0001)
    }

    func testCountdownStopsAtZero() {
        let countdown = Countdown(startedAt: start, duration: 10)

        let state = countdown.state(at: start.addingTimeInterval(12), stepped: true)

        XCTAssertEqual(state, Countdown.State(progress: 1, secondsLeft: 0))
    }

    func testReduceMotionScheduleTicksOnWholeSeconds() {
        let schedule = CountdownSchedule(startedAt: start, stepped: true)

        let ticks = Array(schedule.entries(from: start.addingTimeInterval(0.3), mode: .normal).prefix(3))

        XCTAssertEqual(ticks.map { $0.timeIntervalSince(start) }, [0, 1, 2])
    }

    func testSmoothScheduleTicksFasterThanOncePerSecond() {
        let schedule = CountdownSchedule(startedAt: start, stepped: false)

        let ticks = Array(schedule.entries(from: start, mode: .normal).prefix(2))

        XCTAssertLessThan(ticks[1].timeIntervalSince(ticks[0]), 0.1)
    }
}

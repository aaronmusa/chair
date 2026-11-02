//
//  WatchScoreViewSnapshotTests.swift
//  ChairWatchTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import ChairKit

@testable import ChairWatch

@MainActor
final class WatchScoreViewSnapshotTests: XCTestCase {
    private let actions = WatchScoreActions(onScore: { _ in }, onUndo: {})

    func testWatchScoreIdle() {
        assertWatchSnapshot(of: page(WatchHomeViewSnapshotTests.state), named: "idle")
    }

    func testWatchScoreOverlay() {
        assertWatchSnapshot(of: page(WatchHomeViewSnapshotTests.state, announcement: "Double fault"), named: "overlay")
        assertWatchSnapshot(of: page(WatchHomeViewSnapshotTests.state, showsCorrection: true, waiting: true), named: "correction")
    }

    func testWatchScoreDoubles() {
        var state = WatchHomeViewSnapshotTests.state
        state.names = [.a1: "Aaron", .a2: "Ana", .b1: "Ben", .b2: "Cy"]
        state.score.server = .b2
        state.serve = .second
        assertWatchSnapshot(of: page(state), named: "doubles")
    }

    func testWatchScoreLargeText() {
        assertWatchSnapshot(
            of: page(WatchHomeViewSnapshotTests.state),
            named: "ax",
            dynamicTypeSize: .accessibility3,
            sizes: [.mm41]
        )
    }

    func testWatchScoreAlwaysOn() {
        assertWatchSnapshot(
            of: page(WatchHomeViewSnapshotTests.state, announcement: "Fifteen all").environment(\.isLuminanceReduced, true),
            named: "dimmed"
        )
    }

    func testWatchScoreWorkout() {
        var view = page(WatchHomeViewSnapshotTests.state)
        view.heartRate = 128
        view.notice = WatchWorkoutController.fallbackNotice
        assertWatchSnapshot(of: view, named: "workout")
    }

    func testWatchControls() {
        assertWatchSnapshot(of: WatchControlsPage { _ in }, named: "controls")
    }

    private func page(
        _ state: WatchState,
        announcement: String? = nil,
        showsCorrection: Bool = false,
        waiting: Bool = false
    ) -> WatchScorePage {
        WatchScorePage(
            state: state,
            announcement: announcement,
            showsCorrection: showsCorrection,
            isWaitingForPhone: waiting,
            requiresHold: true,
            actions: actions
        )
    }
}

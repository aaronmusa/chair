//
//  WatchSetStartSnapshotTests.swift
//  ChairWatchTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import ChairKit

@testable import ChairWatch

@MainActor
final class WatchSetStartSnapshotTests: XCTestCase {
    private var doubles: WatchState {
        var state = WatchHomeViewSnapshotTests.state
        state.names = [.a1: "Aaron", .a2: "Ana", .b1: "Ben", .b2: "Cy"]
        state.score = ScoreSnapshot(sets: [SetScore(a: 6, b: 4)], currentSet: SetScore(a: 0, b: 0), currentGame: .loveAll, server: .a1)
        state.phase = .getSet
        state.deuceReceiver = .a1
        return state
    }

    func testWatchSetStartServe() {
        let view = WatchSetStartView(card: .serve(first: .a1, second: .a2), state: doubles) { _ in }
        assertWatchSnapshot(of: view, named: "serve")
    }

    func testWatchSetStartDeuce() {
        let view = WatchSetStartView(card: .deuce(current: .a1, partner: .a2), state: doubles) { _ in }
        assertWatchSnapshot(of: view, named: "deuce")
    }

    func testWatchResult() {
        var state = WatchHomeViewSnapshotTests.state
        state.phase = .complete
        state.score.sets = [SetScore(a: 6, b: 4), SetScore(a: 3, b: 6), SetScore(a: 7, b: 6)]
        state.score.currentSet = SetScore(a: 0, b: 0)
        state.winner = .a
        assertWatchSnapshot(of: WatchResultView(state: state) {}, named: "result")
    }

    func testWatchEndMatch() {
        assertWatchSnapshot(of: WatchEndMatchPage(onEnd: { _ in }), named: "closed")
        assertWatchSnapshot(of: WatchEndMatchPage(onEnd: { _ in }, isChoosing: true), named: "choosing")
    }
}

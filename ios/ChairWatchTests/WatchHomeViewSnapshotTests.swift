//
//  WatchHomeViewSnapshotTests.swift
//  ChairWatchTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import ChairKit

@testable import ChairWatch

@MainActor
final class WatchHomeViewSnapshotTests: XCTestCase {
    private let actions = WatchHomeActions(onJoin: {}, onNewMatch: {}, onRetry: {})

    func testWatchHomeJoin() {
        assertWatchSnapshot(of: home(.join(Self.state)), named: "join")
        assertWatchSnapshot(of: home(.join(Self.state)), named: "join-ax", dynamicTypeSize: .accessibility3)
    }

    func testWatchHomeStartOnPhone() {
        assertWatchSnapshot(of: home(.startOnPhone(lastResult: "vs Juan · 6–4 6–3")), named: "start")
        assertWatchSnapshot(of: home(.startOnPhone(lastResult: nil), asked: true), named: "asked")
    }

    func testWatchHomeUnreachable() {
        assertWatchSnapshot(of: home(.unreachable), named: "unreachable")
        assertWatchSnapshot(of: home(.updatePhone), named: "update")
    }

    private func home(
        _ content: WatchHomeContent,
        asked: Bool = false
    ) -> WatchHomeView {
        WatchHomeView(content: content, hasAskedForNewMatch: asked, actions: actions)
    }

    static let state = WatchState(
        matchID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
        names: [.a1: "Aaron", .b1: "Juan"],
        mySide: .a,
        score: ScoreSnapshot(
            sets: [SetScore(a: 6, b: 4)],
            currentSet: SetScore(a: 2, b: 1),
            currentGame: .standard(a: .thirty, b: .fifteen),
            server: .a1
        ),
        serverCourtSide: .ad,
        serve: .first,
        phase: .rally
    )
}

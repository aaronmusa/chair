//
//  InvitesViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import SnapshotTesting

@testable import Chair

@MainActor
final class InvitesViewSnapshotTests: XCTestCase {
    func testInvites() async {
        let invites = [
            Invite(
                matchID: UUID(),
                ownerHandle: "aaron",
                ownerDisplayName: "Aaron",
                playedAt: Fixtures.matchDay,
                format: .singles,
                status: .completed,
                sets: [SetScore(a: 6, b: 4), SetScore(a: 3, b: 6), SetScore(a: 7, b: 6)]
            ),
            Invite(
                matchID: UUID(),
                ownerHandle: "lia",
                ownerDisplayName: "Lia",
                playedAt: Fixtures.matchDay,
                format: .doubles,
                status: .inProgress,
                sets: [SetScore(a: 2, b: 1)]
            ),
        ]
        let center = InviteCenter(remote: FakeInviteRemote(invites: invites), auth: FakeAuthService(signedIn: true), sync: nil)
        await center.refresh()
        for (name, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            assertSnapshot(
                of: UIHostingController(rootView: InvitesView(center: center)),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: style)),
                named: name
            )
        }
    }
}

//
//  SupabaseLinkingTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport
import Supabase

extension SupabaseMatchRemoteTests {
    @MainActor
    func testUnlinkingAnAcceptedLinkRemovesTheMatchFromTheOtherPlayerAndPrunesTheirCopy() async throws {
        let owner = try await Self.device(signedInAs: "aaron@chair.test")
        let invitee = try await Self.device(signedInAs: "juan@chair.test")
        let inviteeClient = try await Self.client(signedInAs: "juan@chair.test")
        let match = Match(playedAt: .now, format: .singles, createdAt: .now, updatedAt: .now)
        match.players = [MatchPlayer.sample(.a1, name: "Aaron", at: .now), MatchPlayer.sample(.b1, name: "Juan", at: .now)]
        match.link(.b1, to: Self.juan, at: .now)
        try owner.repository.save(match)
        try await owner.repository.sync(as: Self.aaron)
        try await inviteeClient.rpc("respond_to_invite", params: InviteAnswer(matchID: match.remoteID, accept: true)).execute()
        try await invitee.repository.sync(as: Self.juan)
        XCTAssertTrue(try invitee.repository.fetch().contains { $0.remoteID == match.remoteID })

        match.unlink(.b1, at: .now)
        try owner.repository.save(match)
        try await owner.repository.sync(as: Self.aaron)
        try await invitee.repository.sync(as: Self.juan)

        let stored = try await owner.remote.match(id: match.remoteID)
        XCTAssertNil(stored?.players.first { $0.slot == .b1 }?.userID)
        XCTAssertEqual(stored?.players.first { $0.slot == .b1 }?.name, "Juan")
        let listed: [IDRow] = try await inviteeClient.from("my_matches").select("id").eq("id", value: match.remoteID).execute().value
        XCTAssertTrue(listed.isEmpty)
        XCTAssertFalse(try invitee.repository.fetch().contains { $0.remoteID == match.remoteID })

        try await owner.remote.delete(id: match.remoteID)
    }

    @MainActor
    func testThreeSessionsAnInviteeSeesTheMatchFromTheirSideAndAThirdUserSeesNothing() async throws {
        let owner = try await Self.device(signedInAs: "aaron@chair.test")
        let invitee = try await Self.device(signedInAs: "juan@chair.test")
        let inviteeClient = try await Self.client(signedInAs: "juan@chair.test")
        let strangerClient = try await Self.client(signedInAs: "test@chair.local")
        let match = Match(playedAt: .now, format: .singles, createdAt: .now, updatedAt: .now)
        match.players = [MatchPlayer.sample(.a1, name: "Aaron", at: .now), MatchPlayer.sample(.b1, name: "Juan", at: .now)]
        var log = try MatchLog(rules: MatchRules())
        try log.append(TimedEvent(.pointWon(by: .a, outcome: nil, ending: nil), at: .now))
        match.update(from: log, at: .now)
        match.link(.b1, to: Self.juan, at: .now)
        try owner.repository.save(match)
        try await owner.repository.sync(as: Self.aaron)

        try await assertStrangerSeesNothing(strangerClient, matchID: match.remoteID)
        let invites = try await SupabaseInviteRemote(client: inviteeClient).pendingInvites()
        let invite = try XCTUnwrap(invites.first { $0.matchID == match.remoteID })
        XCTAssertEqual(invite.ownerHandle, "aaron")

        try await SupabaseInviteRemote(client: inviteeClient).respond(to: match.remoteID, accept: true)
        try await invitee.repository.sync(as: Self.juan)

        try await assertStrangerSeesNothing(strangerClient, matchID: match.remoteID)
        let copy = try XCTUnwrap(invitee.repository.fetch().first { $0.remoteID == match.remoteID })
        XCTAssertEqual(copy.localUserSlot, .b1)
        XCTAssertEqual(copy.record.mySide, .b)
        XCTAssertEqual(copy.record.opponentNames, "Aaron")
        XCTAssertTrue(copy.record.isReadOnly)
        XCTAssertEqual(copy.orderedPoints.count, match.orderedPoints.count)
        let left = try await SupabaseInviteRemote(client: inviteeClient).pendingInvites()
        XCTAssertFalse(left.contains { $0.matchID == match.remoteID })

        try await owner.remote.delete(id: match.remoteID)
    }

    @MainActor
    private func assertStrangerSeesNothing(
        _ client: SupabaseClient,
        matchID: UUID
    ) async throws {
        for view in ["matches", "my_matches"] {
            let rows: [IDRow] = try await client.from(view).select("id").eq("id", value: matchID).execute().value
            XCTAssertTrue(rows.isEmpty, "\(view) leaks the match")
        }
        let invites = try await SupabaseInviteRemote(client: client).pendingInvites()
        XCTAssertFalse(invites.contains { $0.matchID == matchID })
    }
}

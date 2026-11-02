//
//  InvitesTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class InvitesTests: XCTestCase {
    private let owner = UUID()
    private let invitee = UUID()
    private var container: ModelContainer?

    private var invite: Invite {
        Invite(
            matchID: UUID(),
            ownerHandle: "aaron",
            ownerDisplayName: "Aaron",
            playedAt: Fixtures.matchDay,
            format: .singles,
            status: .completed,
            sets: [SetScore(a: 6, b: 4)]
        )
    }

    func testPendingInvitesAreListedAndAcceptingAnswersAndRemovesIt() async {
        let invite = invite
        let remote = FakeInviteRemote(invites: [invite])
        let center = InviteCenter(remote: remote, auth: FakeAuthService(signedIn: true), sync: nil)

        await center.refresh()
        XCTAssertEqual(center.count, 1)
        XCTAssertEqual(center.bannerText, "1 match invite")

        await center.accept(invite)

        let answers = await remote.answers
        XCTAssertEqual(answers, [invite.matchID: true])
        XCTAssertEqual(center.count, 0)
    }

    func testADeclinedInviteLeavesTheList() async {
        let invite = invite
        let remote = FakeInviteRemote(invites: [invite])
        let center = InviteCenter(remote: remote, auth: FakeAuthService(signedIn: true), sync: nil)
        await center.refresh()

        await center.decline(invite)

        let answers = await remote.answers
        XCTAssertEqual(answers, [invite.matchID: false])
        XCTAssertTrue(center.invites.isEmpty)
    }

    func testSignedOutThereAreNoInvites() async {
        let center = InviteCenter(remote: FakeInviteRemote(invites: [invite]), auth: FakeAuthService(), sync: nil)

        await center.refresh()

        XCTAssertEqual(center.count, 0)
    }

    func testAnInviteShowsDateFormatAndScore() {
        XCTAssertTrue(InvitesView.detail(invite).hasSuffix("Singles · 6–4"))
    }

    func testAnAcceptedMatchShowsTheInviterOnTheFarSideAndTheResultFromTheInviteesView() throws {
        let (match, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))
        let record = linked(match).record

        let row = try XCTUnwrap(MatchListModel(records: [record]).sections.first?.rows.first)

        XCTAssertEqual(row.title, "vs Aaron")
        XCTAssertEqual(row.badge, "L")
        XCTAssertEqual(row.setLine, "0–6 0–6")
    }

    func testTheSummaryPutsTheInviteeFirstAndIsReadOnly() throws {
        let (match, log) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))

        let summary = MatchSummaryModel(record: linked(match).record, log: log)

        XCTAssertEqual(summary.names[.a], "Juan")
        XCTAssertEqual(summary.names[.b], "Aaron")
        XCTAssertEqual(summary.setLine, "0–6 0–6")
        XCTAssertEqual(summary.rows.first, MatchSummaryModel.StatRow(title: "Points won", a: "0", b: "48"))
        XCTAssertEqual(summary.result, "Aaron def. Juan")
        XCTAssertTrue(summary.isReadOnly)
        XCTAssertEqual(summary.ownerID, owner)
    }

    func testThePlayTilesCountFromTheInviteesSide() throws {
        let (match, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))

        let model = PlayHomeModel(records: [linked(match).record], now: Fixtures.matchDay)

        XCTAssertEqual(model.winLoss, "0–1")
    }

    func testALinkedMatchOpensReadOnlyWithoutFixOrDelete() throws {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext)
        let (match, _) = try SummaryFixture.make(events: [SummaryFixture.point(.a)])
        try repository.save(linked(match))
        let viewModel = MatchSessionViewModel(
            matchID: match.remoteID,
            repository: repository,
            clock: FixedClock(Fixtures.matchDay),
            asksHowPointEnded: false
        )

        viewModel.load()

        XCTAssertTrue(viewModel.isReadOnly)
        XCTAssertEqual(viewModel.phase, .complete)
        let row = try XCTUnwrap(MatchListModel(records: [match.record]).sections.first?.rows.first)
        XCTAssertFalse(row.isInProgress, "an in-progress linked match opens its summary, not the live session")
    }

    private func linked(_ match: Match) -> Match {
        match.ownerID = owner
        match.localUserSlot = .b1
        match.players.first { $0.slot == .a1 }?.userID = owner
        match.players.first { $0.slot == .a1 }?.linkStatus = .accepted
        match.players.first { $0.slot == .b1 }?.userID = invitee
        match.players.first { $0.slot == .b1 }?.linkStatus = .accepted
        return match
    }
}

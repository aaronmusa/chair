//
//  LinkingTests.swift
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
final class LinkingTests: XCTestCase {
    private let juan = PublicProfile(id: UUID(), handle: "juan", displayName: "Juan Reyes", level: .intermediate)
    private let aaronM = PublicProfile(id: UUID(), handle: "aaron_m", displayName: "Aaron M")
    private var container: ModelContainer?

    func testTypingShowsPrefixMatchesOnHandleWithoutTheUsersOwnProfile() async throws {
        let own = PublicProfile(id: FakeAuthService.sampleSession.userID, handle: "aaron", displayName: "Aaron")
        let viewModel = picker(profiles: ["aaron": own, "aaron_m": aaronM, "juan": juan]) { _ in }

        viewModel.query = "aar"
        try await waitUntil { !viewModel.results.isEmpty }

        XCTAssertEqual(viewModel.results.map(\.handle), ["aaron_m"])
    }

    func testAScannedPlayerCodeIsPicked() async {
        var picked: PublicProfile?
        let viewModel = picker(profiles: ["juan": juan]) { picked = $0 }

        await viewModel.scanned("chair://user/juan")

        XCTAssertEqual(picked, juan)
    }

    func testAnotherQRCodeIsRejected() async {
        let viewModel = picker(profiles: [:]) { _ in }

        await viewModel.scanned("https://example.com")

        XCTAssertEqual(viewModel.message, "That QR code isn't a Chair player")
    }

    func testPickingOnNewMatchLinksThePlayerAndTheUploadQueueHoldsIt() throws {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = SyncingMatchRepository(context: container.mainContext, remote: FakeMatchRemote())
        let viewModel = NewMatchViewModel(
            defaults: MatchDefaults(),
            repository: repository,
            clock: FixedClock(Fixtures.matchDay),
            auth: FakeAuthService(signedIn: true)
        )

        viewModel.link(.b1, to: juan)
        let matchID = try XCTUnwrap(viewModel.start())

        let match = try XCTUnwrap(repository.fetch().first { $0.remoteID == matchID })
        let opponent = try XCTUnwrap(match.players.first { $0.slot == .b1 })
        XCTAssertEqual(opponent.userID, juan.id)
        XCTAssertEqual(opponent.linkStatus, .pending)
        XCTAssertEqual(opponent.name, "Juan Reyes")
        XCTAssertGreaterThan(try repository.pendingCount(), 0)
    }

    func testTheYouRowHasNoLinkAction() {
        let viewModel = NewMatchViewModel(
            defaults: MatchDefaults(),
            repository: nil,
            clock: FixedClock(Fixtures.matchDay),
            auth: FakeAuthService(signedIn: true)
        )

        XCTAssertFalse(viewModel.canLink(.a1))
        XCTAssertTrue(viewModel.canLink(.b1))
    }

    func testLinkingWhileSignedOutAsksToSignIn() async {
        let viewModel = NewMatchViewModel(
            defaults: MatchDefaults(),
            repository: nil,
            clock: FixedClock(Fixtures.matchDay),
            auth: FakeAuthService()
        )

        await viewModel.requestLink(.b1)

        XCTAssertTrue(viewModel.isShowingSignIn)
        XCTAssertNil(viewModel.pickerSlot)
    }

    func testUnlinkOnTheSummaryMakesTheRowFreeTextAndQueuesIt() throws {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = SyncingMatchRepository(context: container.mainContext, remote: FakeMatchRemote())
        let match = Match.sample()
        match.link(.b1, to: juan.id, at: Fixtures.matchDay)
        match.players.first { $0.slot == .b1 }?.linkStatus = .accepted
        try repository.save(match)
        let viewModel = MatchLinksViewModel(matchID: match.remoteID, repository: repository, environment: .fakes())
        viewModel.reload()
        XCTAssertEqual(viewModel.rows, [MatchLinksViewModel.Row(slot: .b1, name: "Reyes", status: .accepted)])

        viewModel.unlink(.b1)

        XCTAssertEqual(viewModel.rows, [MatchLinksViewModel.Row(slot: .b1, name: "Reyes", status: .none)])
        XCTAssertNil(match.players.first { $0.slot == .b1 }?.userID)
        XCTAssertEqual(match.syncState, .pendingUpload)
    }

    func testAUserLinkOpensTheirProfileOrFeedsAnOpenPicker() throws {
        let router = AppRouter()
        let link = try XCTUnwrap(URL(string: "chair://user/Juan"))

        XCTAssertTrue(router.handle(link))
        XCTAssertEqual(router.publicProfileHandle, "juan")

        router.publicProfileHandle = nil
        router.isPickingOpponent = true
        XCTAssertTrue(router.handle(link))
        XCTAssertEqual(router.pickedHandle, "juan")
        XCTAssertNil(router.publicProfileHandle)
    }

    func testABadUserLinkIsIgnored() throws {
        let router = AppRouter()

        XCTAssertFalse(try router.handle(XCTUnwrap(URL(string: "chair://user/a!"))))
        XCTAssertFalse(try router.handle(XCTUnwrap(URL(string: "chair://user"))))
    }

    func testAProfileCodeEncodesTheUserLink() {
        XCTAssertEqual(PlayerQRCode.url(for: "aaron")?.absoluteString, "chair://user/aaron")
        XCTAssertNotNil(PlayerQRCode.image(for: "aaron"))
    }

    private func picker(
        profiles: [String: PublicProfile],
        onPick: @escaping (PublicProfile) -> Void
    ) -> OpponentPickerViewModel {
        var environment = AppEnvironment.fakes()
        environment.profileRemote = FakeProfileRemote(publicProfiles: profiles)
        return OpponentPickerViewModel(environment: environment, debounce: .zero, onPick: onPick)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 100 where !condition() {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(condition())
    }
}

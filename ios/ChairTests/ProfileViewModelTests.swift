//
//  ProfileViewModelTests.swift
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
final class ProfileViewModelTests: XCTestCase {
    private var container: ModelContainer?

    func testATakenHandleShowsTakenAndSaveIsDisabledAndAFreeOneIsAvailable() async throws {
        let viewModel = try await loadedViewModel()

        viewModel.handle = "aaron_m"
        try await settle(viewModel)
        XCTAssertEqual(viewModel.handleStatus, .taken)
        XCTAssertEqual(viewModel.handleStatus.text, "Taken")
        XCTAssertFalse(viewModel.canSave)

        viewModel.handle = "aaron_m2"
        try await settle(viewModel)
        XCTAssertEqual(viewModel.handleStatus, .available)
        XCTAssertEqual(viewModel.handleStatus.text, "Available")
        XCTAssertTrue(viewModel.canSave)
    }

    func testABadlyFormedHandleIsRejectedWithoutAsking() async throws {
        let viewModel = try await loadedViewModel()

        viewModel.handle = "a!"

        XCTAssertEqual(viewModel.handleStatus, .invalid)
        XCTAssertFalse(viewModel.canSave)
    }

    func testTheCurrentHandleCountsAsUnchanged() async throws {
        let viewModel = try await loadedViewModel()

        viewModel.handle = "AARON"

        XCTAssertEqual(viewModel.handleStatus, .unchanged)
    }

    func testSavingStoresTheProfileAndUploadsIt() async throws {
        let remote = FakeProfileRemote()
        let viewModel = try await loadedViewModel(remote: remote)
        viewModel.displayName = "Aaron Musa"
        viewModel.hand = .right
        viewModel.homeCourt = "Rizal"

        await viewModel.save()

        let updates = await remote.updates
        XCTAssertEqual(updates.last?.displayName, "Aaron Musa")
        XCTAssertEqual(updates.last?.hand, .right)
        XCTAssertEqual(updates.last?.homeCourt, "Rizal")
        XCTAssertFalse(viewModel.canSave)
    }

    func testDeletingTakesTwoStepsThenSignsOutAndClearsTheDevice() async throws {
        let auth = FakeAuthService(signedIn: true)
        let store = InMemoryAccountStore(lastUserID: FakeAuthService.sampleSession.userID)
        var signedOut = 0
        let container = try InMemoryModelContainer()
        self.container = container
        let matches = LocalMatchRepository(context: container.mainContext)
        try matches.save(Match.sample())
        let profiles = ProfileRepository(context: container.mainContext, remote: FakeProfileRemote())
        var environment = AppEnvironment.fakes()
        environment.auth = auth
        let viewModel = ProfileViewModel(
            environment: environment,
            profiles: profiles,
            matches: matches,
            accountStore: store,
            debounce: .zero
        ) { signedOut += 1 }
        await viewModel.load()

        viewModel.requestDelete()
        XCTAssertEqual(viewModel.deleteStep, .confirm)
        viewModel.confirmDelete()
        XCTAssertEqual(viewModel.deleteStep, .final)
        await viewModel.deleteAccount()

        let calls = await auth.calls
        let session = await auth.currentSession()
        XCTAssertTrue(calls.contains("deleteAccount"))
        XCTAssertNil(session)
        XCTAssertTrue(try matches.fetch().isEmpty)
        XCTAssertNil(try profiles.current())
        XCTAssertNil(store.lastUserID)
        XCTAssertEqual(signedOut, 1)
    }

    func testThePublicProfileShowsTheMatchesWithYouCount() async {
        let other = PublicProfile(id: UUID(), handle: "juan", displayName: "Juan", level: .intermediate)
        var environment = AppEnvironment.fakes()
        environment.profileRemote = FakeProfileRemote(publicProfiles: ["juan": other], linkedCounts: [other.id: 3])
        let viewModel = PublicProfileViewModel(handle: "juan", environment: environment)

        await viewModel.load()

        XCTAssertEqual(viewModel.profile, other)
        XCTAssertEqual(viewModel.matchesWithYou, 3)
    }

    func testInitialsComeFromTheFirstTwoWords() {
        XCTAssertEqual(AvatarView.initials(for: "Aaron Musa"), "AM")
        XCTAssertEqual(AvatarView.initials(for: "player"), "P")
        XCTAssertEqual(AvatarView.initials(for: " "), "?")
    }

    private func loadedViewModel(remote: FakeProfileRemote = FakeProfileRemote()) async throws -> ProfileViewModel {
        let container = try InMemoryModelContainer()
        self.container = container
        var environment = AppEnvironment.fakes()
        environment.profileRemote = remote
        let viewModel = ProfileViewModel(
            environment: environment,
            profiles: ProfileRepository(context: container.mainContext, remote: remote),
            matches: nil,
            accountStore: InMemoryAccountStore(),
            debounce: .zero
        ) {}
        await viewModel.load()
        return viewModel
    }

    private func settle(_ viewModel: ProfileViewModel) async throws {
        for _ in 0 ..< 100 where viewModel.handleStatus == .checking {
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

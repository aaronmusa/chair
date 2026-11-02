//
//  ProfileViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftData
import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import SnapshotTesting

@testable import Chair

@MainActor
final class ProfileViewSnapshotTests: XCTestCase {
    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let typeSize: DynamicTypeSize
    }

    private var container: ModelContainer?
    private var hosts: [UIViewController] = []

    private let variants = [
        Variant(name: "light", style: .light, typeSize: .large),
        Variant(name: "dark", style: .dark, typeSize: .large),
        Variant(name: "ax5", style: .light, typeSize: .accessibility5),
    ]

    func testOwnProfile() async throws {
        let container = try InMemoryModelContainer()
        self.container = container
        let profile = ProfileRecord(
            id: FakeAuthService.sampleSession.userID,
            handle: "aaron",
            displayName: "Aaron Musa",
            homeCourt: "Rizal Memorial",
            hand: .right,
            level: .intermediate
        )
        for variant in variants {
            let remote = FakeProfileRemote(profile: profile)
            var environment = AppEnvironment.fakes()
            environment.profileRemote = remote
            let viewModel = ProfileViewModel(
                environment: environment,
                profiles: ProfileRepository(context: container.mainContext, remote: remote),
                matches: nil,
                accountStore: InMemoryAccountStore()
            ) {}
            await viewModel.load()
            let view = NavigationStack { ProfileView(viewModel: viewModel) }
                .environment(\.dynamicTypeSize, variant.typeSize)
            let host = UIHostingController(rootView: view)
            hosts.append(host)
            assertSnapshot(
                of: host,
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: variant.name
            )
        }
    }

    func testPublicProfile() async {
        let juan = PublicProfile(id: UUID(), handle: "juan", displayName: "Juan Reyes", level: .advanced)
        for variant in variants {
            var environment = AppEnvironment.fakes()
            environment.profileRemote = FakeProfileRemote(publicProfiles: ["juan": juan], linkedCounts: [juan.id: 4])
            let viewModel = PublicProfileViewModel(handle: "juan", environment: environment)
            await viewModel.load()
            let view = NavigationStack { PublicProfileView(viewModel: viewModel) }
                .environment(\.dynamicTypeSize, variant.typeSize)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: variant.name
            )
        }
    }
}

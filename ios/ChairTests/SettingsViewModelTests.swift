//
//  SettingsViewModelTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/2/26.
//

import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testItStartsFromTheSavedDefaults() {
        let store = FakeMatchDefaultsStore(MatchDefaults(format: .doubles, deuce: .noAd))

        let viewModel = SettingsViewModel(environment: environment(store: store))

        XCTAssertEqual(viewModel.defaults.format, .doubles)
        XCTAssertEqual(viewModel.defaults.deuce, .noAd)
    }

    func testChangingADefaultSavesIt() {
        let store = FakeMatchDefaultsStore()
        let viewModel = SettingsViewModel(environment: environment(store: store))

        viewModel.defaults.format = .doubles
        viewModel.defaults.deuce = .noAd

        XCTAssertEqual(store.load().format, .doubles)
        XCTAssertEqual(store.load().deuce, .noAd)
        XCTAssertEqual(store.saves, 2)
    }

    func testANewMatchOpenedAfterwardsSeesTheChangedDefaults() {
        let store = FakeMatchDefaultsStore()
        let viewModel = SettingsViewModel(environment: environment(store: store))

        viewModel.defaults.format = .doubles
        viewModel.defaults.deuce = .noAd

        let opened = store.load()
        XCTAssertEqual(opened.format, .doubles)
        XCTAssertEqual(opened.rules.deuce, .noAd)
        XCTAssertEqual(opened.playerAName, "You")
    }

    func testSignedOutShowsNotSignedIn() async {
        let viewModel = SettingsViewModel(environment: environment(store: FakeMatchDefaultsStore()))

        await viewModel.refreshAccount()

        XCTAssertEqual(viewModel.accountStatus, "Not signed in")
    }

    func testSignedInShowsSignedIn() async {
        var env = environment(store: FakeMatchDefaultsStore())
        env.auth = FakeAuthService(signedIn: true)
        let viewModel = SettingsViewModel(environment: env)

        await viewModel.refreshAccount()

        XCTAssertEqual(viewModel.accountStatus, "Signed in")
    }

    func testVersionAndBuildComeFromTheBundle() {
        let viewModel = SettingsViewModel(
            environment: environment(store: FakeMatchDefaultsStore()),
            info: ["CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "42"]
        )

        XCTAssertEqual(viewModel.version, "1.2.0")
        XCTAssertEqual(viewModel.build, "42")
    }

    private func environment(store: FakeMatchDefaultsStore) -> AppEnvironment {
        var environment = AppEnvironment.fakes()
        environment.matchDefaults = store
        return environment
    }
}

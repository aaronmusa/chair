//
//  SettingsViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import SnapshotTesting

@testable import Chair

@MainActor
final class SettingsViewSnapshotTests: XCTestCase {
    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let typeSize: DynamicTypeSize
    }

    func testSettings() {
        let variants = [
            Variant(name: "light", style: .light, typeSize: .large),
            Variant(name: "dark", style: .dark, typeSize: .large),
            Variant(name: "ax5", style: .light, typeSize: .accessibility5),
        ]
        for variant in variants {
            var environment = AppEnvironment.fakes()
            environment.matchDefaults = FakeMatchDefaultsStore(MatchDefaults(playerName: "Aaron"))
            let viewModel = SettingsViewModel(
                environment: environment,
                info: ["CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1"]
            )
            let umpire = UmpireCoordinator(speech: FakeSpeechOutput(), settings: .fake())
            let view = NavigationStack { SettingsView(viewModel: viewModel) }
                .environment(\.umpire, umpire)
                .environment(\.dynamicTypeSize, variant.typeSize)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: variant.name
            )
        }
    }
}

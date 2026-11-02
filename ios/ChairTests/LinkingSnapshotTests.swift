//
//  LinkingSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import ChairUI
import SnapshotTesting

@testable import Chair

@MainActor
final class LinkingSnapshotTests: XCTestCase {
    func testOpponentPicker() async throws {
        var environment = AppEnvironment.fakes()
        environment.profileRemote = FakeProfileRemote(publicProfiles: [
            "juan": PublicProfile(id: UUID(), handle: "juan", displayName: "Juan Reyes"),
            "juana": PublicProfile(id: UUID(), handle: "juana", displayName: "Juana Cruz"),
        ])
        let viewModel = OpponentPickerViewModel(environment: environment, debounce: .zero) { _ in }
        viewModel.query = "ju"
        for _ in 0 ..< 100 where viewModel.results.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        for (name, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            assertSnapshot(
                of: UIHostingController(rootView: OpponentPickerView(viewModel: viewModel)),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: style)),
                named: name
            )
        }
    }

    func testLinkChips() {
        let chips = VStack(alignment: .leading, spacing: Spacing.chair.sm) {
            LinkChip(status: .pending)
            LinkChip(status: .accepted)
            LinkChip(status: .declined)
        }
        .padding()
        .background(Color.chair.surface)
        for (name, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            assertSnapshot(
                of: UIHostingController(rootView: chips),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: style)),
                named: name
            )
        }
    }
}

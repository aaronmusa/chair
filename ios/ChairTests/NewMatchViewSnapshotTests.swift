//
//  NewMatchViewSnapshotTests.swift
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
final class NewMatchViewSnapshotTests: XCTestCase {
    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let typeSize: DynamicTypeSize
    }

    private let variants = [
        Variant(name: "light", style: .light, typeSize: .large),
        Variant(name: "dark", style: .dark, typeSize: .large),
        Variant(name: "ax5", style: .light, typeSize: .accessibility5),
    ]

    func testSingles() {
        assertVariants(MatchDefaults())
    }

    func testDoubles() {
        assertVariants(MatchDefaults(format: .doubles))
    }

    private func assertVariants(
        _ defaults: MatchDefaults,
        testName: String = #function,
        line: UInt = #line
    ) {
        for variant in variants {
            let viewModel = NewMatchViewModel(defaults: defaults, repository: nil, clock: FixedClock(Fixtures.matchDay))
            let view = NavigationStack { NewMatchView(viewModel: viewModel, onStart: { _, _ in }) }
                .environment(\.dynamicTypeSize, variant.typeSize)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: variant.name,
                testName: testName,
                line: line
            )
        }
    }
}

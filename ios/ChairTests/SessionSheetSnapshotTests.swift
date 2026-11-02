//
//  SessionSheetSnapshotTests.swift
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
final class SessionSheetSnapshotTests: XCTestCase {
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

    func testOutcomeSheet() {
        assertVariants {
            OutcomeSheet(winnerName: "Juan", isServerWinning: false, onChoose: { _, _ in })
        }
    }

    func testPointLogSheet() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(TimedEvent(.pointWon(by: .a, outcome: .winner, ending: nil), at: Fixtures.matchDay))
        try log.append(TimedEvent(.pointWon(by: .b, outcome: .unforcedError, ending: .net), at: Fixtures.matchDay))
        try log.append(TimedEvent(.pointWon(by: .b, outcome: nil, ending: nil), at: Fixtures.matchDay))
        let points = log.currentGamePoints
        assertVariants {
            PointLogSheet(points: points, names: [.a: "Aaron", .b: "Juan"], onFlip: { _ in })
        }
    }

    private func assertVariants(
        testName: String = #function,
        line: UInt = #line,
        @ViewBuilder _ content: () -> some View
    ) {
        for variant in variants {
            let view = content().environment(\.dynamicTypeSize, variant.typeSize)
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

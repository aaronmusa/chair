//
//  MatchSummaryViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI
import XCTest

import ChairKit
import SnapshotTesting

@testable import Chair

@MainActor
final class MatchSummaryViewSnapshotTests: XCTestCase {
    private let regular = ViewImageConfig(
        safeArea: .zero,
        size: CGSize(width: 1180, height: 820),
        traits: UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.horizontalSizeClass = .regular
            traits.verticalSizeClass = .regular
            traits.displayScale = 2
        }
    )

    func testSummaryCompact() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            try assertSummary(.compact, config: .iPhone13, style: style, named: style == .dark ? "dark" : "light")
        }
        try assertSummary(.compact, config: .iPhone13, style: .light, typeSize: .accessibility5, named: "ax5")
    }

    func testSummaryRegular() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            try assertSummary(.regular, config: regular, style: style, named: style == .dark ? "dark" : "light")
        }
    }

    private func assertSummary(
        _ sizeClass: UserInterfaceSizeClass,
        config: ViewImageConfig,
        style: UIUserInterfaceStyle,
        typeSize: DynamicTypeSize = .large,
        named name: String,
        testName: String = #function,
        line: UInt = #line
    ) throws {
        var events: [MatchEvent] = []
        let pattern: [MatchEvent] = [
            SummaryFixture.point(.a, .ace), SummaryFixture.point(.b, .unforcedError), SummaryFixture.point(.a, .winner),
            SummaryFixture.point(.b, .winner), .fault, SummaryFixture.point(.a, .forcedError), SummaryFixture.point(.a),
        ]
        for _ in 0 ..< 8 {
            events += pattern
        }
        let (match, log) = try SummaryFixture.make(events: events)
        let view = MatchSummaryView(model: MatchSummaryModel(match: match, log: log))
            .environment(\.horizontalSizeClass, sizeClass)
            .environment(\.dynamicTypeSize, typeSize)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: config, traits: UITraitCollection(userInterfaceStyle: style)),
            named: name,
            testName: testName,
            line: line
        )
    }
}

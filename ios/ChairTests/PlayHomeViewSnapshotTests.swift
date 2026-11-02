//
//  PlayHomeViewSnapshotTests.swift
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
final class PlayHomeViewSnapshotTests: XCTestCase {
    func testPlayHomeCompact() throws {
        try assertStyles(.compact, config: .iPhone13)
    }

    func testPlayHomeRegular() throws {
        try assertStyles(.regular, config: .iPadPro11(.landscape))
    }

    private func assertStyles(
        _ sizeClass: UserInterfaceSizeClass,
        config: ViewImageConfig,
        testName: String = #function,
        line: UInt = #line
    ) throws {
        let finished = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48)).0
        let live = try SummaryFixture.make(events: [SummaryFixture.point(.a)]).0
        let model = PlayHomeModel(records: [finished.record, live.record], now: Fixtures.matchDay.addingTimeInterval(3600))
        for style in [UIUserInterfaceStyle.light, .dark] {
            let view = NavigationStack { PlayHomeView(model: model) }
                .environment(\.horizontalSizeClass, sizeClass)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: config, traits: UITraitCollection(userInterfaceStyle: style)),
                named: style == .dark ? "dark" : "light",
                testName: testName,
                line: line
            )
        }
    }
}

//
//  RallyViewSnapshotTests.swift
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
final class RallyViewSnapshotTests: XCTestCase {
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

    func testCompact() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            try assertRally(.compact, config: .iPhone13, style: style, named: style == .dark ? "dark" : "light")
        }
    }

    func testRegular() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            try assertRally(.regular, config: regular, style: style, named: style == .dark ? "dark" : "light")
        }
    }

    func testCompactAX5KeepsThePointButtons() throws {
        try assertRally(.compact, config: .iPhone13, style: .light, typeSize: .accessibility5, named: "ax5")
    }

    private func assertRally(
        _ sizeClass: UserInterfaceSizeClass,
        config: ViewImageConfig,
        style: UIUserInterfaceStyle,
        typeSize: DynamicTypeSize = .large,
        named name: String,
        testName: String = #function,
        line: UInt = #line
    ) throws {
        var log = try MatchLog(rules: MatchRules())
        var calls: [Announcement] = []
        for side in [Side.a, .a, .b] {
            calls = try log.append(TimedEvent(.pointWon(by: side, outcome: nil, ending: nil), at: .distantPast))
        }
        let names: [PlayerSlot: String] = [.a1: "Aaron", .b1: "Juan"]
        let view = RallyView(
            scoreboard: ScoreboardModel(state: log.state, names: [.a: "Aaron", .b: "Juan"]),
            getSet: GetSetPresentation(state: log.state, names: names, announcements: calls),
            announcement: "Thirty–fifteen",
            names: [.a: "Aaron", .b: "Juan"]
        )
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

//
//  GetSetViewSnapshotTests.swift
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
final class GetSetViewSnapshotTests: XCTestCase {
    private let names: [PlayerSlot: String] = [.a1: "Aaron", .a2: "Bea", .b1: "Juan", .b2: "Lia"]

    func testSingles() throws {
        try assertSizeClasses(.singles)
    }

    func testDoubles() throws {
        try assertSizeClasses(.doubles)
    }

    private func assertSizeClasses(
        _ format: MatchFormat,
        testName: String = #function,
        line: UInt = #line
    ) throws {
        var log = try MatchLog(rules: MatchRules(), format: format)
        let calls = try log.append(TimedEvent(.pointWon(by: .a, outcome: nil, ending: nil), at: .distantPast))
        let presentation = GetSetPresentation(state: log.state, names: names, announcements: calls)
        let configs: [UserInterfaceSizeClass: ViewImageConfig] = [
            .compact: .iPhone13,
            .regular: .iPadPro11(.landscape),
        ]
        for (sizeClass, config) in configs {
            let view = GetSetView(presentation: presentation)
                .environment(\.horizontalSizeClass, sizeClass)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: config),
                named: sizeClass == .regular ? "regular" : "compact",
                testName: testName,
                line: line
            )
        }
    }
}

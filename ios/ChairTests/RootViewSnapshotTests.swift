//
//  RootViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 10/31/26.
//

import SwiftUI
import XCTest

import SnapshotTesting

@testable import Chair

@MainActor
final class RootViewSnapshotTests: XCTestCase {
    func testCompactShowsTabs() {
        assertBothSchemes(.compact, config: .iPhone13)
    }

    func testRegularShowsTheSidebar() {
        assertBothSchemes(.regular, config: .iPadPro11(.landscape))
    }

    private func assertBothSchemes(
        _ sizeClass: UserInterfaceSizeClass,
        config: ViewImageConfig,
        testName: String = #function,
        line: UInt = #line
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let root = RootView()
                .environment(\.appRouter, AppRouter())
                .environment(\.horizontalSizeClass, sizeClass)
            assertSnapshot(
                of: UIHostingController(rootView: root),
                as: .image(on: config, traits: UITraitCollection(userInterfaceStyle: style)),
                named: style == .dark ? "dark" : "light",
                testName: testName,
                line: line
            )
        }
    }
}

//
//  PlaceholderViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/14/26.
//

import SwiftUI
import XCTest

import SnapshotTesting

@testable import Chair

@MainActor
final class PlaceholderViewSnapshotTests: XCTestCase {
    func testTrainAndCoachShowWhatIsComing() {
        for section in [AppSection.train, .coach] {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let view = NavigationStack { PlaceholderView(section: section) }
                assertSnapshot(
                    of: UIHostingController(rootView: view),
                    as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: style)),
                    named: "\(section.rawValue)-\(style == .dark ? "dark" : "light")"
                )
            }
        }
    }
}

//
//  ScoreFixSheetSnapshotTests.swift
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
final class ScoreFixSheetSnapshotTests: XCTestCase {
    func testScoreFixSheet() {
        var state = MatchState.initial(rules: MatchRules())
        state.sets = [SetScore(a: 6, b: 4)]
        state.currentSet = SetScore(a: 2, b: 3)
        state.currentGame = .standard(a: .thirty, b: .forty)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let sheet = ScoreFixSheet(
                draft: ScoreFixDraft(state: state),
                names: [.a: "Aaron", .b: "Juan"],
                slotNames: [.a1: "Aaron", .b1: "Juan"],
                onApply: { _ in nil },
                onCancel: {}
            )
            assertSnapshot(
                of: UIHostingController(rootView: sheet),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: style)),
                named: style == .dark ? "dark" : "light"
            )
        }
    }
}

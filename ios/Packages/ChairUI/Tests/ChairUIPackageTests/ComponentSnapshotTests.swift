//
//  ComponentSnapshotTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI
import XCTest

import SnapshotTesting

@testable import ChairUI

@MainActor
final class ComponentSnapshotTests: XCTestCase {
    func testButton() {
        assertEveryAppearance(ChairButtonPreview())
    }

    func testCard() {
        assertEveryAppearance(ChairCardPreview())
    }

    func testPill() {
        assertEveryAppearance(ChairPillPreview())
    }

    func testSegmented() {
        assertEveryAppearance(ChairSegmentedPreview())
    }

    func testRow() {
        assertEveryAppearance(ChairRowPreview())
    }

    func testSheet() {
        assertEveryAppearance(ChairSheetPreview())
    }

    func testCountdownRing() {
        assertEveryAppearance(
            HStack(spacing: Spacing.chair.md) {
                CountdownRingFace(progress: 0.4, secondsLeft: 3, size: .small)
                CountdownRingFace(progress: 0.7, secondsLeft: 3, size: .regular)
            }
            .padding(Spacing.chair.md)
            .background(Color.chair.surface)
        )
    }

    private func assertEveryAppearance(
        _ view: some View,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        for appearance in Appearance.all {
            let framed = view
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 393)
                .environment(\.colorScheme, appearance.scheme)
                .environment(\.dynamicTypeSize, appearance.size)
            assertSnapshot(
                of: framed,
                as: .image(layout: .sizeThatFits),
                named: appearance.name,
                file: file,
                testName: testName,
                line: line
            )
        }
    }
}

private struct Appearance {
    let name: String
    let scheme: ColorScheme
    let size: DynamicTypeSize

    static let all = [
        Appearance(name: "light", scheme: .light, size: .large),
        Appearance(name: "dark", scheme: .dark, size: .large),
        Appearance(name: "ax5", scheme: .light, size: .accessibility5),
    ]
}

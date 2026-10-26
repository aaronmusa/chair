//
//  ColorTokenGridSnapshotTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI
import XCTest

import SnapshotTesting

@testable import ChairUI

@MainActor
final class ColorTokenGridSnapshotTests: XCTestCase {
    func testColorTokenGridInLight() {
        assertSnapshot(of: grid(.light), as: .image)
    }

    func testColorTokenGridInDark() {
        assertSnapshot(of: grid(.dark), as: .image)
    }

    private func grid(_ scheme: ColorScheme) -> some View {
        ColorTokenGrid()
            .frame(width: 393)
            .environment(\.colorScheme, scheme)
    }
}

//
//  TypeScaleSnapshotTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI
import XCTest

import SnapshotTesting

@testable import ChairUI

@MainActor
final class TypeScaleSnapshotTests: XCTestCase {
    func testEveryStyleAtDefaultAndAX5() {
        for style in ChairTextStyle.allCases {
            for (size, name) in [(DynamicTypeSize.large, "default"), (.accessibility5, "ax5")] {
                let row = TypeScaleRow(style: style)
                    .padding(Spacing.chair.md)
                    .frame(width: 393, alignment: .leading)
                    .background(Color.chair.surface)
                    .environment(\.dynamicTypeSize, size)

                assertSnapshot(of: row, as: .image(layout: .sizeThatFits), named: "\(style.rawValue)-\(name)")
            }
        }
    }
}

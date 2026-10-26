//
//  TypeScaleTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI
import UIKit
import XCTest

@testable import ChairUI

@MainActor
final class TypeScaleTests: XCTestCase {
    func testScoreKeepsTwoDigitsOnOneLineAtAX5InTheMiniCourtWidth() {
        let twoDigits = fittedHeight(Text("40").chairFont(.score), size: .accessibility5, width: 110)
        let oneDigit = fittedHeight(Text("4").chairFont(.score), size: .accessibility5, width: 110)

        XCTAssertEqual(twoDigits, oneDigit, accuracy: 0.5)
    }

    func testEveryStyleGrowsWithDynamicType() {
        for style in ChairTextStyle.allCases {
            let text = Text(style.sample).chairFont(style)
            let standard = fittedHeight(text, size: .large, width: 10000)
            let largest = fittedHeight(text, size: .accessibility5, width: 10000)

            XCTAssertGreaterThan(largest, standard * 1.4, "\(style.rawValue) does not scale with Dynamic Type")
        }
    }

    func testScaleValuesMatchTheTokens() {
        XCTAssertEqual(Spacing.chair.scale.map(\.value), [4, 8, 12, 16, 20, 24, 32])
        XCTAssertEqual(Radius.chair.scale.map(\.value), [8, 10, 12, 16])
        XCTAssertEqual(Stroke.chair.scale.map(\.value), [1, 1.5, 2])
    }

    private func fittedHeight(
        _ view: some View,
        size: DynamicTypeSize,
        width: CGFloat
    ) -> CGFloat {
        let controller = UIHostingController(rootView: view.environment(\.dynamicTypeSize, size))
        return controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}

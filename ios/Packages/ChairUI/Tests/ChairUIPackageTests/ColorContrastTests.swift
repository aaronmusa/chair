//
//  ColorContrastTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/26/26.
//

import UIKit
import XCTest

@testable import ChairUI

final class ColorContrastTests: XCTestCase {
    func testEveryTokenHasALightAndADarkValue() {
        for token in ChairColorToken.allCases {
            for style in [UIUserInterfaceStyle.light, .dark] {
                XCTAssertNotNil(resolved(token, style), "\(token.rawValue) is missing in \(name(style))")
            }
        }
    }

    func testDarkModeInvertsInkAndSurface() throws {
        try assertSameColour(resolved(.ink, .light), resolved(.surface, .dark))
        try assertSameColour(resolved(.surface, .light), resolved(.ink, .dark))
    }

    private func assertSameColour(
        _ first: RGB?,
        _ second: RGB?,
        line: UInt = #line
    ) throws {
        let first = try XCTUnwrap(first, line: line)
        let second = try XCTUnwrap(second, line: line)
        let tolerance = 0.5 / 255
        XCTAssertEqual(first.red, second.red, accuracy: tolerance, "\(first) vs \(second)", line: line)
        XCTAssertEqual(first.green, second.green, accuracy: tolerance, "\(first) vs \(second)", line: line)
        XCTAssertEqual(first.blue, second.blue, accuracy: tolerance, "\(first) vs \(second)", line: line)
    }

    func testEveryTextPairMeetsTheMinimumContrastInBothModes() throws {
        for pair in ChairColorPair.all {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let text = try XCTUnwrap(resolved(pair.text, style))
                let background = try XCTUnwrap(resolved(pair.background, style))
                let ratio = text.contrast(with: background)
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    pair.minimumContrast,
                    "\(pair) is \(String(format: "%.2f", ratio)):1 in \(name(style))"
                )
            }
        }
    }

    private func resolved(_ token: ChairColorToken, _ style: UIUserInterfaceStyle) -> RGB? {
        let traits = UITraitCollection(userInterfaceStyle: style)
        guard let color = UIColor(named: token.rawValue, in: .module, compatibleWith: traits) else { return nil }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGB(red: red, green: green, blue: blue)
    }

    private func name(_ style: UIUserInterfaceStyle) -> String {
        style == .dark ? "dark" : "light"
    }
}

private struct RGB: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    var luminance: Double {
        0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrast(with other: RGB) -> Double {
        let lighter = max(luminance, other.luminance)
        let darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func linear(_ channel: CGFloat) -> Double {
        let value = Double(channel)
        return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}

//
//  AppIconRenderTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/14/26.
//

import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XCTest

import ChairUI

@MainActor
final class AppIconRenderTests: XCTestCase {
    private static let outputFolder = ProcessInfo.processInfo.environment["CHAIR_ICON_OUT"]

    func testRenderAppIcons() throws {
        guard let path = Self.outputFolder else {
            throw XCTSkip("Run through make icon")
        }
        let assets = URL(fileURLWithPath: path)
        let phone = assets.appendingPathComponent("Chair/Resources/Assets.xcassets/AppIcon.appiconset")
        for variant in AppIconVariant.allCases {
            let name = variant == .light ? "AppIcon.png" : "AppIcon-\(variant.rawValue.capitalized).png"
            try write(AppIconArt(variant), to: phone.appendingPathComponent(name))
        }
        try write(AppIconArt(.light), to: assets.appendingPathComponent("ChairWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
    }

    private func write(
        _ view: some View,
        to url: URL
    ) throws {
        let renderer = ImageRenderer(content: view.frame(width: 1024, height: 1024))
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.cgImage)
        let opaque = try XCTUnwrap(Self.withoutAlpha(image))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, opaque, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private static func withoutAlpha(_ image: CGImage) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context?.makeImage()
    }
}

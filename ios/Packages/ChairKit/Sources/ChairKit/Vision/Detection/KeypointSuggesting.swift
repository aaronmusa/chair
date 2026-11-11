//
//  KeypointSuggesting.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/12/26.
//

import CoreGraphics
import CoreVideo
import Foundation

public protocol KeypointSuggesting: Sendable {
    func suggest(
        in image: LumaImage,
        placement: CameraPlacement,
        frameSize: CGSize
    ) async -> CourtSuggestion
}

public struct CourtLineSuggester: KeypointSuggesting {
    public init() {}

    public func suggest(
        in image: LumaImage,
        placement: CameraPlacement,
        frameSize: CGSize
    ) async -> CourtSuggestion {
        await Task.detached(priority: .userInitiated) {
            CourtLineDetector.suggest(in: image, placement: placement, frameSize: frameSize)
        }.value
    }
}

public extension LumaImage {
    static func from(_ frame: Frame) async -> LumaImage? {
        await Task.detached(priority: .userInitiated) {
            LumaImage(pixelBuffer: frame.pixelBuffer)
        }.value
    }

    var meanLuminance: Double {
        guard !pixels.isEmpty else { return 0 }
        var total = 0
        for index in stride(from: 0, to: pixels.count, by: 16) {
            total += Int(pixels[index])
        }
        return Double(total) / Double((pixels.count + 15) / 16)
    }

    func cgImage() -> CGImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

public extension LineMask {
    func cgImage() -> CGImage? {
        LumaImage(width: width, height: height, pixels: isLine.map { $0 ? 255 : 0 }).cgImage()
    }
}

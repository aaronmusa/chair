//
//  LumaImage.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import CoreVideo
import Foundation

public struct LumaImage: Sendable {
    public let width: Int
    public let height: Int
    public internal(set) var pixels: [UInt8]

    public init(
        width: Int,
        height: Int,
        pixels: [UInt8]
    ) {
        precondition(pixels.count == width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.init(width: width, height: height, pixels: pixels)
    }

    public init?(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let planar = [kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange].contains(format)
        guard planar || format == kCVPixelFormatType_32BGRA else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let base = planar ? CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) : CVPixelBufferGetBaseAddress(pixelBuffer)
        let rowBytes = planar ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) : CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let source = base?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0 ..< height {
            let row = source + y * rowBytes
            for x in 0 ..< width {
                if planar {
                    pixels[y * width + x] = row[x]
                } else {
                    let b = Int(row[x * 4])
                    let g = Int(row[x * 4 + 1])
                    let r = Int(row[x * 4 + 2])
                    pixels[y * width + x] = UInt8((r * 77 + g * 150 + b * 29) >> 8)
                }
            }
        }
        self.init(width: width, height: height, pixels: pixels)
    }

    public subscript(
        x: Int,
        y: Int
    ) -> UInt8 {
        pixels[y * width + x]
    }
}

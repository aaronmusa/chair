//
//  LineMask.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation

public struct LineMask: Sendable {
    public static let maximumWidth = 1920
    public static let window = 7
    public static let contrast = 6
    public static let minimumLuma = 70
    public static let distanceCap: Float = 40

    public let width: Int
    public let height: Int
    public let scale: Double
    public let isLine: [Bool]
    public let distance: [Float]
    let paint: [SIMD2<Double>]

    public init(
        _ image: LumaImage,
        maximumWidth: Int = LineMask.maximumWidth
    ) {
        self.init(raw: Self.threshold(image), width: image.width, height: image.height, maximumWidth: maximumWidth)
    }

    public static func pyramid(
        _ image: LumaImage,
        coarseWidth: Int
    ) -> (coarse: LineMask, fine: LineMask) {
        let raw = threshold(image)
        return (
            LineMask(raw: raw, width: image.width, height: image.height, maximumWidth: coarseWidth),
            LineMask(raw: raw, width: image.width, height: image.height, maximumWidth: maximumWidth)
        )
    }

    private init(
        raw: [Bool],
        width sourceWidth: Int,
        height sourceHeight: Int,
        maximumWidth: Int
    ) {
        let factor = max(1, Int((Double(sourceWidth) / Double(maximumWidth)).rounded(.up)))
        let width = sourceWidth / factor
        let height = sourceHeight / factor
        var pooled = [Bool](repeating: false, count: width * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                var any = false
                for dy in 0 ..< factor where !any {
                    let row = (y * factor + dy) * sourceWidth
                    for dx in 0 ..< factor where raw[row + x * factor + dx] {
                        any = true
                        break
                    }
                }
                pooled[y * width + x] = any
            }
        }
        self.width = width
        self.height = height
        scale = 1 / Double(factor)
        isLine = pooled
        distance = Self.distanceTransform(pooled, width: width, height: height)
        paint = Self.paintSample(pooled, width: width, height: height, limit: width <= 640 ? 250 : Self.paintLimit)
    }

    static let paintLimit = 500

    private static func paintSample(
        _ mask: [Bool],
        width: Int,
        height: Int,
        limit: Int
    ) -> [SIMD2<Double>] {
        let total = mask.count { $0 }
        guard total > 0 else { return [] }
        let stride = max(1, total / limit)
        var points: [SIMD2<Double>] = []
        var seen = 0
        for index in mask.indices where mask[index] {
            if seen % stride == 0 {
                points.append(SIMD2(Double(index % width), Double(index / width)))
            }
            seen += 1
        }
        return points
    }

    public func hitRate(within limit: Float) -> Double {
        Double(distance.count { $0 <= limit }) / Double(max(distance.count, 1))
    }

    public var lineFraction: Double {
        Double(isLine.count { $0 }) / Double(max(isLine.count, 1))
    }

    public func distance(
        atX x: Double,
        y: Double
    ) -> Float? {
        let column = Int(x.rounded())
        let row = Int(y.rounded())
        guard column >= 0, row >= 0, column < width, row < height else { return nil }
        return distance[row * width + column]
    }

    private static func threshold(_ source: LumaImage) -> [Bool] {
        let image = blurred(source)
        let width = image.width
        let height = image.height
        var integral = [Int](repeating: 0, count: (width + 1) * (height + 1))
        image.pixels.withUnsafeBufferPointer { pixels in
            for y in 0 ..< height {
                var rowSum = 0
                for x in 0 ..< width {
                    rowSum += Int(pixels[y * width + x])
                    integral[(y + 1) * (width + 1) + x + 1] = integral[y * (width + 1) + x + 1] + rowSum
                }
            }
        }
        var mask = [Bool](repeating: false, count: width * height)
        let r = window
        image.pixels.withUnsafeBufferPointer { pixels in
            for y in 0 ..< height {
                let y0 = max(0, y - r)
                let y1 = min(height, y + r + 1)
                for x in 0 ..< width {
                    let value = Int(pixels[y * width + x])
                    guard value >= minimumLuma else { continue }
                    let x0 = max(0, x - r)
                    let x1 = min(width, x + r + 1)
                    let sum = integral[y1 * (width + 1) + x1] - integral[y0 * (width + 1) + x1]
                        - integral[y1 * (width + 1) + x0] + integral[y0 * (width + 1) + x0]
                    let mean = sum / ((x1 - x0) * (y1 - y0))
                    guard value >= mean + contrast else { continue }
                    mask[y * width + x] = isRidge(Raster(pixels: pixels, width: width, height: height), x: x, y: y, value: value)
                }
            }
        }
        return mask
    }

    private static let ridgeSpans = [2, 5, 12]
    private static let ridgeDirections = [(1, 0), (0, 1), (1, 1), (1, -1)]

    private struct Raster {
        let pixels: UnsafeBufferPointer<UInt8>
        let width: Int
        let height: Int
    }

    private static func isRidge(
        _ raster: Raster,
        x: Int,
        y: Int,
        value: Int
    ) -> Bool {
        let pixels = raster.pixels
        let width = raster.width
        let height = raster.height
        for span in ridgeSpans {
            for (dx, dy) in ridgeDirections {
                let ax = x - dx * span
                let ay = y - dy * span
                let bx = x + dx * span
                let by = y + dy * span
                guard ax >= 0, bx >= 0, ax < width, bx < width, ay >= 0, by >= 0, ay < height, by < height else { continue }
                let side = max(Int(pixels[ay * width + ax]), Int(pixels[by * width + bx]))
                if value - side >= contrast {
                    return true
                }
            }
        }
        return false
    }

    private static func blurred(_ image: LumaImage) -> LumaImage {
        let width = image.width
        let height = image.height
        var out = image.pixels
        image.pixels.withUnsafeBufferPointer { pixels in
            for y in 1 ..< max(1, height - 1) {
                for x in 1 ..< max(1, width - 1) {
                    var sum = 0
                    for dy in -1 ... 1 {
                        let row = (y + dy) * width + x
                        sum += Int(pixels[row - 1]) + Int(pixels[row]) * 2 + Int(pixels[row + 1])
                    }
                    out[y * width + x] = UInt8(sum / 12)
                }
            }
        }
        return LumaImage(width: width, height: height, pixels: out)
    }

    private static func distanceTransform(
        _ mask: [Bool],
        width: Int,
        height: Int
    ) -> [Float] {
        var d = mask.map { $0 ? 0 : distanceCap }
        forwardPass(&d, width: width, height: height)
        backwardPass(&d, width: width, height: height)
        return d
    }

    private static let straight: Float = 1
    private static let diagonal: Float = 1.4142

    private static func forwardPass(
        _ d: inout [Float],
        width: Int,
        height: Int
    ) {
        for y in 0 ..< height {
            for x in 0 ..< width {
                let i = y * width + x
                var best = d[i]
                if x > 0 { best = min(best, d[i - 1] + straight) }
                if y > 0 {
                    best = min(best, d[i - width] + straight)
                    if x > 0 { best = min(best, d[i - width - 1] + diagonal) }
                    if x < width - 1 { best = min(best, d[i - width + 1] + diagonal) }
                }
                d[i] = best
            }
        }
    }

    private static func backwardPass(
        _ d: inout [Float],
        width: Int,
        height: Int
    ) {
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) {
                let i = y * width + x
                var best = d[i]
                if x < width - 1 { best = min(best, d[i + 1] + straight) }
                if y < height - 1 {
                    best = min(best, d[i + width] + straight)
                    if x < width - 1 { best = min(best, d[i + width + 1] + diagonal) }
                    if x > 0 { best = min(best, d[i + width - 1] + diagonal) }
                }
                d[i] = best
            }
        }
    }
}

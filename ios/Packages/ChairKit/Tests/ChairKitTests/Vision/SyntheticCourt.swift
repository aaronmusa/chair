//
//  SyntheticCourt.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import Foundation

import ChairKit

struct SyntheticCourt {
    struct Clutter {
        var players = 0
        var fence = false
        var noise = 0
    }

    static let lineWidth = 0.05
    static let piece = 0.5

    let camera: PinholeCamera
    var clutter = Clutter()

    func render(seed: UInt64 = 1) -> LumaImage? {
        let width = Int(camera.size.width)
        let height = Int(camera.size.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setShouldAntialias(true)
        fill(context, gray: 97, rect: CGRect(x: 0, y: 0, width: width, height: height))
        let doubles = CourtDimensions.halfDoublesWidth
        let half = CourtDimensions.halfLength
        quad(context, gray: 74, from: CourtPoint(x: -doubles, y: -half), to: CourtPoint(x: doubles, y: half), slices: 24)
        for segment in CourtModel.lines {
            line(context, segment)
        }
        var generator = SeededGenerator(seed: seed)
        if clutter.fence {
            fill(context, gray: 235, rect: CGRect(x: 0, y: CGFloat(height) * 0.12, width: CGFloat(width), height: 3))
        }
        for _ in 0 ..< clutter.players {
            let x = Double.random(in: 0 ... Double(width) - 40, using: &generator)
            let y = Double.random(in: Double(height) * 0.35 ... Double(height) - 120, using: &generator)
            fill(context, gray: .random(in: 20 ... 60, using: &generator), rect: CGRect(x: x, y: y, width: 36, height: 110))
        }
        guard let image = context.makeImage(), let luma = LumaImage(cgImage: image) else { return nil }
        guard clutter.noise > 0 else { return luma }
        let noisy = luma.pixels.map { pixel in
            UInt8(clamping: Int(pixel) + Int.random(in: -clutter.noise ... clutter.noise, using: &generator))
        }
        return LumaImage(width: luma.width, height: luma.height, pixels: noisy)
    }

    private func line(
        _ context: CGContext,
        _ segment: CourtModel.Segment
    ) {
        let along = CourtPoint(x: segment.to.x - segment.from.x, y: segment.to.y - segment.from.y)
        let length = max(hypot(along.x, along.y), 1e-9)
        let normal = CourtPoint(x: -along.y / length * Self.lineWidth / 2, y: along.x / length * Self.lineWidth / 2)
        let pieces = max(1, Int(length / Self.piece))
        for index in 0 ..< pieces {
            let t0 = Double(index) / Double(pieces)
            let t1 = Double(index + 1) / Double(pieces)
            let a = CourtPoint(x: segment.from.x + along.x * t0, y: segment.from.y + along.y * t0)
            let b = CourtPoint(x: segment.from.x + along.x * t1, y: segment.from.y + along.y * t1)
            polygon(context, gray: 238, corners: [
                CourtPoint(x: a.x + normal.x, y: a.y + normal.y),
                CourtPoint(x: b.x + normal.x, y: b.y + normal.y),
                CourtPoint(x: b.x - normal.x, y: b.y - normal.y),
                CourtPoint(x: a.x - normal.x, y: a.y - normal.y),
            ])
        }
    }

    private func quad(
        _ context: CGContext,
        gray: Int,
        from: CourtPoint,
        to: CourtPoint,
        slices: Int
    ) {
        for index in 0 ..< slices {
            let y0 = from.y + (to.y - from.y) * Double(index) / Double(slices)
            let y1 = from.y + (to.y - from.y) * Double(index + 1) / Double(slices)
            polygon(context, gray: gray, corners: [
                CourtPoint(x: from.x, y: y0), CourtPoint(x: to.x, y: y0), CourtPoint(x: to.x, y: y1), CourtPoint(x: from.x, y: y1),
            ])
        }
    }

    private func polygon(
        _ context: CGContext,
        gray: Int,
        corners: [CourtPoint]
    ) {
        let pixels = corners.compactMap(camera.project)
        guard pixels.count == corners.count else { return }
        context.setFillColor(gray: CGFloat(gray) / 255, alpha: 1)
        context.beginPath()
        context.addLines(between: pixels)
        context.closePath()
        context.fillPath()
    }

    private func fill(
        _ context: CGContext,
        gray: Int,
        rect: CGRect
    ) {
        context.setFillColor(gray: CGFloat(gray) / 255, alpha: 1)
        context.fill(rect)
    }
}

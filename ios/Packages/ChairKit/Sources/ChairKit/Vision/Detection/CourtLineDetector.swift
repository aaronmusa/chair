//
//  CourtLineDetector.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import Foundation
import simd

public struct CourtSuggestion: Equatable, Sendable {
    public let keypoints: [CourtKeypoint: CGPoint]
    public let confidence: Double

    public static let none = CourtSuggestion(keypoints: [:], confidence: 0)

    public init(
        keypoints: [CourtKeypoint: CGPoint],
        confidence: Double
    ) {
        self.keypoints = keypoints
        self.confidence = confidence
    }
}

public enum CourtLineDetector {
    public static let minimumConfidence = 0.5
    static let sampleSpacing = 0.25
    static let onLineDistance: Float = 2.5
    static let coarseWidth = 480
    static let coarseCap: Float = 24
    static let fineCap: Float = 6

    public static func suggest(
        in image: LumaImage,
        placement: CameraPlacement,
        frameSize: CGSize
    ) -> CourtSuggestion {
        guard let fit = fit(image, placement: placement) else { return .none }
        let confidence = confidence(fit.pose, space: fit.space, mask: fit.mask, samples: modelSamples())
        guard confidence >= minimumConfidence else { return CourtSuggestion(keypoints: [:], confidence: confidence) }
        let toFrame = Double(frameSize.width) / Double(fit.mask.width)
        let cropOffset = (Double(fit.mask.height) * toFrame - Double(frameSize.height)) / 2
        let frame = CGRect(origin: .zero, size: frameSize)
        var keypoints: [CourtKeypoint: CGPoint] = [:]
        for keypoint in CourtKeypoint.defaultSet(for: placement) {
            guard let pixel = fit.space.project(keypoint.court, pose: fit.pose) else { continue }
            let point = CGPoint(x: pixel.x * toFrame, y: pixel.y * toFrame - cropOffset)
            if frame.contains(point) {
                keypoints[keypoint] = point
            }
        }
        return CourtSuggestion(keypoints: keypoints, confidence: confidence)
    }

    struct Fit {
        let pose: PoseSpace.Pose
        let space: PoseSpace
        let mask: LineMask
        let coarse: LineMask
        let coarseSpace: PoseSpace
    }

    static func fit(
        _ image: LumaImage,
        placement: CameraPlacement
    ) -> Fit? {
        let masks = LineMask.pyramid(image, coarseWidth: coarseWidth)
        let fine = masks.fine
        guard fine.lineFraction > 0.0005, fine.lineFraction < 0.25 else { return nil }
        let coarseSpace = PoseSpace(placement: placement, maskWidth: masks.coarse.width, maskHeight: masks.coarse.height)
        let fineSpace = PoseSpace(placement: placement, maskWidth: fine.width, maskHeight: fine.height)
        let sparse = modelSamples(spacing: 0.5)
        let dense = modelSamples(spacing: sampleSpacing)
        let seeds = coarseSpace.seeds()
            .map { ($0, objective($0, space: coarseSpace, mask: masks.coarse, samples: sparse, cap: coarseCap)) }
            .sorted { $0.1 < $1.1 }
            .prefix(24)
        let rough = concurrentMap(Array(seeds)) { seed -> (PoseSpace.Pose, Double) in
            var pose = refine(seed.0, space: coarseSpace, mask: masks.coarse, samples: sparse, cap: coarseCap)
            pose = polish(pose, space: coarseSpace, mask: masks.coarse, samples: sparse, cap: coarseCap / 2, evaluations: 300)
            return (pose, objective(pose, space: coarseSpace, mask: masks.coarse, samples: sparse, cap: coarseCap / 2))
        }
        .sorted { $0.1 < $1.1 }
        .prefix(4)
        let best = concurrentMap(Array(rough)) { candidate -> (PoseSpace.Pose, Double) in
            var pose = candidate.0
            for cap in [coarseCap, coarseCap / 2, fineCap] {
                pose = refine(pose, space: fineSpace, mask: fine, samples: dense, cap: cap)
                pose = polish(pose, space: fineSpace, mask: fine, samples: dense, cap: cap, evaluations: 400)
            }
            return (pose, objective(pose, space: fineSpace, mask: fine, samples: dense, cap: fineCap))
        }
        .min { $0.1 < $1.1 }
        return best.map { Fit(pose: $0.0, space: fineSpace, mask: fine, coarse: masks.coarse, coarseSpace: coarseSpace) }
    }

    private final class Slots<U>: @unchecked Sendable {
        var values: [U?]

        init(count: Int) {
            values = Array(repeating: nil, count: count)
        }
    }

    private static func concurrentMap<T: Sendable, U>(
        _ items: [T],
        _ transform: @escaping @Sendable (T) -> U
    ) -> [U] {
        let slots = Slots<U>(count: items.count)
        slots.values.withUnsafeMutableBufferPointer { buffer in
            let base = UncheckedPointer(buffer: buffer)
            DispatchQueue.concurrentPerform(iterations: items.count) { index in
                base.buffer[index] = transform(items[index])
            }
        }
        return slots.values.compactMap(\.self)
    }

    private struct UncheckedPointer<U>: @unchecked Sendable {
        let buffer: UnsafeMutableBufferPointer<U?>
    }

    struct ModelSamples {
        let points: [CourtPoint]
        let weights: [Double]
    }

    static func modelSamples(spacing: Double = sampleSpacing) -> ModelSamples {
        var points: [CourtPoint] = []
        var weights: [Double] = []
        for segment in CourtModel.lines {
            let length = segment.from.distance(to: segment.to)
            let count = max(1, Int(length / spacing))
            for i in 0 ... count {
                let t = Double(i) / Double(count)
                points.append(CourtPoint(
                    x: segment.from.x + (segment.to.x - segment.from.x) * t,
                    y: segment.from.y + (segment.to.y - segment.from.y) * t
                ))
                weights.append(1 / Double(count + 1))
            }
        }
        return ModelSamples(points: points, weights: weights)
    }

    static let explainWeight = 0.6

    static func objective(
        _ pose: PoseSpace.Pose,
        space: PoseSpace,
        mask: LineMask,
        samples: ModelSamples,
        cap: Float,
        explains: Bool = true
    ) -> Double {
        let frame = space.frame(pose)
        var total = 0.0
        var seenWeight = 0.0
        var seen = 0
        for (sample, weight) in zip(samples.points, samples.weights) {
            guard let pixel = frame.project(sample), let d = mask.distance(atX: pixel.x, y: pixel.y) else { continue }
            total += Double(min(d, cap)) * weight
            seenWeight += weight
            seen += 1
        }
        guard seen > 20, seenWeight > 0 else { return Double(cap) * 2 }
        let coverage = Double(seen) / Double(samples.points.count)
        let explained = explains ? unexplained(mask.paint, frame: frame, cap: Double(cap)) : 0
        return total / seenWeight + explainWeight * explained + Double(cap) * max(0, 0.3 - coverage) * 4
    }

    static func unexplained(
        _ paint: [SIMD2<Double>],
        frame: PoseSpace.Frame,
        cap: Double
    ) -> Double {
        guard !paint.isEmpty else { return 0 }
        let segments = CourtModel.lines.compactMap { frame.segment($0.from, $0.to) }
        guard !segments.isEmpty else { return cap }
        var total = 0.0
        for point in paint {
            var best = cap * cap
            for (a, b) in segments {
                let ab = b - a
                let length = simd_length_squared(ab)
                let t = length > 0 ? min(max(simd_dot(point - a, ab) / length, 0), 1) : 0
                best = min(best, simd_distance_squared(point, a + ab * t))
            }
            total += best.squareRoot()
        }
        return total / Double(paint.count)
    }

    static func confidence(
        _ pose: PoseSpace.Pose,
        space: PoseSpace,
        mask: LineMask,
        samples: ModelSamples
    ) -> Double {
        var seen = 0
        var onLine = 0
        let frame = space.frame(pose)
        for sample in samples.points {
            guard let pixel = frame.project(sample), let d = mask.distance(atX: pixel.x, y: pixel.y) else { continue }
            seen += 1
            if d <= onLineDistance {
                onLine += 1
            }
        }
        guard Double(seen) >= Double(samples.points.count) * 0.2 else { return 0 }
        let chance = mask.hitRate(within: onLineDistance)
        guard chance < 1 else { return 0 }
        return max(0, (Double(onLine) / Double(seen) - chance) / (1 - chance))
    }
}

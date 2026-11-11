//
//  CourtLineDetector+Search.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/12/26.
//

import Foundation

extension CourtLineDetector {
    static func polish(
        _ start: PoseSpace.Pose,
        space: PoseSpace,
        mask: LineMask,
        samples: ModelSamples,
        cap: Float,
        evaluations: Int = 900
    ) -> PoseSpace.Pose {
        let size = start.values.count
        func score(_ values: [Double]) -> Double {
            objective(PoseSpace.Pose(values: values), space: space, mask: mask, samples: samples, cap: cap)
        }
        func clamped(_ values: [Double]) -> [Double] {
            values.enumerated().map { space.clamp($1, at: $0) }
        }
        var simplex = [start.values]
        for index in 0 ..< size {
            var vertex = start.values
            let range = space.ranges[index]
            vertex[index] = space.clamp(vertex[index] + (range.upperBound - range.lowerBound) * 0.04, at: index)
            simplex.append(vertex)
        }
        var scores = simplex.map(score)
        var used = scores.count
        while used < evaluations {
            let order = scores.indices.sorted { scores[$0] < scores[$1] }
            simplex = order.map { simplex[$0] }
            scores = order.map { scores[$0] }
            if scores[size] - scores[0] < 1e-4 {
                break
            }
            used += step(&simplex, &scores, score: score, clamped: clamped)
        }
        let best = scores.indices.min { scores[$0] < scores[$1] } ?? 0
        return PoseSpace.Pose(values: simplex[best])
    }

    private static func step(
        _ simplex: inout [[Double]],
        _ scores: inout [Double],
        score: ([Double]) -> Double,
        clamped: ([Double]) -> [Double]
    ) -> Int {
        let size = simplex.count - 1
        let centroid = (0 ..< size).map { i in simplex.prefix(size).map { $0[i] }.reduce(0, +) / Double(size) }
        let worst = simplex[size]
        func toward(_ factor: Double) -> [Double] {
            clamped(zip(centroid, worst).map { $0 + factor * ($0 - $1) })
        }
        let reflected = toward(1)
        let reflectedScore = score(reflected)
        if reflectedScore < scores[0] {
            let expanded = toward(2)
            let expandedScore = score(expanded)
            (simplex[size], scores[size]) = expandedScore < reflectedScore ? (expanded, expandedScore) : (reflected, reflectedScore)
            return 2
        }
        if reflectedScore < scores[size - 1] {
            (simplex[size], scores[size]) = (reflected, reflectedScore)
            return 1
        }
        let contracted = toward(-0.5)
        let contractedScore = score(contracted)
        if contractedScore < scores[size] {
            (simplex[size], scores[size]) = (contracted, contractedScore)
            return 2
        }
        for index in 1 ... size {
            simplex[index] = clamped(zip(simplex[0], simplex[index]).map { $0 + 0.5 * ($1 - $0) })
            scores[index] = score(simplex[index])
        }
        return 2 + size
    }

    static func refine(
        _ start: PoseSpace.Pose,
        space: PoseSpace,
        mask: LineMask,
        samples: ModelSamples,
        cap: Float
    ) -> PoseSpace.Pose {
        var pose = start
        var score = objective(pose, space: space, mask: mask, samples: samples, cap: cap)
        var steps = space.ranges.map { ($0.upperBound - $0.lowerBound) / 8 }
        let minimum = space.ranges.map { ($0.upperBound - $0.lowerBound) / 4000 }
        for _ in 0 ..< 400 {
            var improved = false
            for index in pose.values.indices {
                for direction in [1.0, -1.0] {
                    var candidate = pose
                    candidate.values[index] = space.clamp(pose.values[index] + direction * steps[index], at: index)
                    let candidateScore = objective(candidate, space: space, mask: mask, samples: samples, cap: cap)
                    if candidateScore < score {
                        pose = candidate
                        score = candidateScore
                        improved = true
                        break
                    }
                }
            }
            if !improved {
                steps = steps.map { $0 / 2 }
                if zip(steps, minimum).allSatisfy({ $0 < $1 }) {
                    break
                }
            }
        }
        return pose
    }
}

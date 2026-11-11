//
//  FootageSet.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import AVFoundation
import CoreGraphics
import Foundation

import ChairKit

struct FootageManifest: Codable, Equatable {
    var clips: [FootageClip]
}

struct FootageClip: Codable, Equatable {
    enum Surface: String, Codable, CaseIterable { case hard, clay, grass }
    enum Light: String, Codable, CaseIterable { case bright, overcast, evening }

    var id: String
    var file: String
    var court: String
    var surface: Surface
    var placement: CameraPlacement
    var light: Light
    var duration: Double
    var frameRate: Double
    var device: String?
    var height: Double?
    var still: String?

    var frameCount: Int {
        Int((duration * frameRate).rounded())
    }
}

struct GroundTruth: Codable, Equatable {
    struct Point: Codable, Equatable {
        var x: Double
        var y: Double
    }

    struct Size: Codable, Equatable {
        var width: Double
        var height: Double
    }

    struct Mark: Codable, Equatable {
        var keypoint: CourtKeypoint
        var pixel: Point
    }

    struct Keypoints: Codable, Equatable {
        var frame: Int
        var points: [Mark]

        var pixels: [CourtKeypoint: CGPoint] {
            Dictionary(points.map { ($0.keypoint, CGPoint(x: $0.pixel.x, y: $0.pixel.y)) }) { first, _ in first }
        }
    }

    struct GroundPoint: Codable, Equatable {
        var name: String
        var pixel: Point
        var court: Point
    }

    var clip: String
    var frameSize: Size
    var keypoints: [Keypoints]
    var groundPoints: [GroundPoint]
}

struct FootageSet {
    struct Clip {
        let entry: FootageClip
        let groundTruth: GroundTruth?
        let url: URL
    }

    static let keypointInterval = 600
    static let maximumReprojectionError = 3.0
    static let minimumGroundPoints = 10
    static let halfWidth = 5.485
    static let halfLength = 11.885
    static let courtTolerance = 0.01

    let clips: [Clip]
    let strayGroundTruth: [String]
    var folder: URL {
        clips.first?.url.deletingLastPathComponent() ?? URL(filePath: "/")
    }

    static func load(
        manifest: URL,
        groundTruth: URL,
        clips: URL
    ) throws -> FootageSet {
        let decoder = JSONDecoder()
        let entries = try decoder.decode(FootageManifest.self, from: Data(contentsOf: manifest)).clips
        let files = try FileManager.default.contentsOfDirectory(at: groundTruth, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        var truths: [String: GroundTruth] = [:]
        for file in files {
            truths[file.deletingPathExtension().lastPathComponent] = try decoder.decode(
                GroundTruth.self,
                from: Data(contentsOf: file)
            )
        }
        let ids = Set(entries.map(\.id))
        return FootageSet(
            clips: entries.map { Clip(entry: $0, groundTruth: truths[$0.id], url: clips.appending(path: $0.file)) },
            strayGroundTruth: truths.keys.filter { !ids.contains($0) }.sorted()
        )
    }

    var problems: [String] {
        var found = strayGroundTruth.map { "\($0): ground truth with no manifest entry" }
        let ids = clips.map(\.entry.id)
        found += Set(ids.filter { id in ids.count { $0 == id } > 1 }).sorted().map { "\($0): duplicate clip id" }
        for clip in clips {
            found += clip.problems.map { "\(clip.entry.id): \($0)" }
        }
        return found
    }

    func missingFiles() -> [String] {
        clips.flatMap { clip in
            [clip.entry.file] + (clip.entry.still.map { [$0] } ?? [])
        }
        .filter { !FileManager.default.fileExists(atPath: folder.appending(path: $0).path) }
    }

    var clipsWithoutStills: [String] {
        clips.filter { [.netPost, .chair].contains($0.entry.placement) && $0.entry.still == nil }.map(\.entry.id)
    }
}

extension FootageSet.Clip {
    var problems: [String] {
        guard let truth = groundTruth else { return ["no ground truth"] }
        var found: [String] = []
        if truth.clip != entry.id {
            found.append("ground truth names clip \(truth.clip)")
        }
        let expected = Set(stride(from: 0, to: entry.frameCount, by: FootageSet.keypointInterval))
        let marked = Set(truth.keypoints.map(\.frame))
        for frame in expected.subtracting(marked).sorted() {
            found.append("no keypoints at frame \(frame)")
        }
        for keypoints in truth.keypoints {
            found += keypointProblems(keypoints, in: truth.frameSize).map { "frame \(keypoints.frame): \($0)" }
        }
        if truth.groundPoints.count < FootageSet.minimumGroundPoints {
            found.append("\(truth.groundPoints.count) ground points, need \(FootageSet.minimumGroundPoints)")
        }
        for point in truth.groundPoints {
            if !point.court.isOnCourt {
                found.append("\(point.name) lies outside the court")
            }
            if !point.pixel.isInside(truth.frameSize) {
                found.append("\(point.name) lies outside the frame")
            }
        }
        return found
    }

    func mediaProblems() async throws -> [String] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return ["no video track"] }
        let (rate, size) = try await track.load(.nominalFrameRate, .naturalSize)
        let duration = try await asset.load(.duration).seconds
        var found: [String] = []
        if abs(Double(rate) - entry.frameRate) > 1 {
            found.append("frame rate \(rate), manifest says \(entry.frameRate)")
        }
        if abs(duration - entry.duration) > 1 {
            found.append("duration \(duration) s, manifest says \(entry.duration)")
        }
        if let truth = groundTruth, Double(size.width) != truth.frameSize.width || Double(size.height) != truth.frameSize.height {
            found.append("frame \(size.width)×\(size.height), ground truth says \(truth.frameSize.width)×\(truth.frameSize.height)")
        }
        return found
    }

    private func keypointProblems(
        _ keypoints: GroundTruth.Keypoints,
        in size: GroundTruth.Size
    ) -> [String] {
        let pixels = keypoints.pixels
        guard pixels.count == keypoints.points.count else { return ["a keypoint is marked twice"] }
        guard pixels.count >= Homography.minimumPoints else {
            return ["\(pixels.count) keypoints, need \(Homography.minimumPoints)"]
        }
        var found: [String] = []
        let allowed = Set(CourtKeypoint.defaultSet(for: entry.placement))
        for mark in keypoints.points where !allowed.contains(mark.keypoint) {
            found.append("\(mark.keypoint) is not in the \(entry.placement.rawValue) set")
        }
        if !keypoints.points.allSatisfy({ $0.pixel.isInside(size) }) {
            found.append("a keypoint lies outside the frame")
        }
        guard let homography = Homography(pixels) else { return found + ["keypoints do not define a homography"] }
        let error = homography.reprojectionError(pixels)
        if error > FootageSet.maximumReprojectionError {
            found.append("keypoints disagree by \(String(format: "%.1f", error)) px; check their names")
        }
        return found
    }

    func mappingErrors() -> (lines: Double?, baselines: Double?) {
        guard let truth = groundTruth,
              let first = truth.keypoints.min(by: { $0.frame < $1.frame }),
              let homography = Homography(first.pixels) else { return (nil, nil) }
        var lines: [Double] = []
        var baselines: [Double] = []
        for point in truth.groundPoints {
            let court = CourtPoint(x: point.court.x, y: point.court.y)
            let error = homography.toCourt(CGPoint(x: point.pixel.x, y: point.pixel.y))?.distance(to: court) ?? .infinity
            if abs(abs(court.y) - CourtDimensions.halfLength) < FootageSet.courtTolerance {
                baselines.append(error)
            } else {
                lines.append(error)
            }
        }
        return (lines.mean, baselines.mean)
    }
}

private extension [Double] {
    var mean: Double? {
        isEmpty ? nil : reduce(0, +) / Double(count)
    }
}

private extension GroundTruth.Point {
    var isOnCourt: Bool {
        abs(x) <= FootageSet.halfWidth + FootageSet.courtTolerance
            && abs(y) <= FootageSet.halfLength + FootageSet.courtTolerance
    }

    func isInside(_ size: GroundTruth.Size) -> Bool {
        (0 ... size.width).contains(x) && (0 ... size.height).contains(y)
    }
}

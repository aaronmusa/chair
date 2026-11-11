//
//  FootageSet.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import AVFoundation
import Foundation

struct FootageManifest: Codable, Equatable {
    var clips: [FootageClip]
}

struct FootageClip: Codable, Equatable {
    enum Surface: String, Codable, CaseIterable { case hard, clay, grass }
    enum Placement: String, Codable, CaseIterable { case netPost, baseline, chair }
    enum Light: String, Codable, CaseIterable { case bright, overcast, evening }

    var id: String
    var file: String
    var court: String
    var surface: Surface
    var placement: Placement
    var light: Light
    var duration: Double
    var frameRate: Double
    var device: String?

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

    struct Corners: Codable, Equatable {
        var frame: Int
        var points: [Point]
    }

    struct GroundPoint: Codable, Equatable {
        var name: String
        var pixel: Point
        var court: Point
    }

    var clip: String
    var frameSize: Size
    var corners: [Corners]
    var groundPoints: [GroundPoint]
}

struct FootageSet {
    struct Clip {
        let entry: FootageClip
        let groundTruth: GroundTruth?
        let url: URL
    }

    static let cornerInterval = 600
    static let minimumGroundPoints = 10
    static let halfWidth = 5.485
    static let halfLength = 11.885
    static let courtTolerance = 0.01

    let clips: [Clip]
    let strayGroundTruth: [String]

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
        clips.filter { !FileManager.default.fileExists(atPath: $0.url.path) }.map(\.entry.file)
    }
}

extension FootageSet.Clip {
    var problems: [String] {
        guard let truth = groundTruth else { return ["no ground truth"] }
        var found: [String] = []
        if truth.clip != entry.id {
            found.append("ground truth names clip \(truth.clip)")
        }
        let expected = Set(stride(from: 0, to: entry.frameCount, by: FootageSet.cornerInterval))
        let marked = Set(truth.corners.map(\.frame))
        for frame in expected.subtracting(marked).sorted() {
            found.append("no corners at frame \(frame)")
        }
        for corners in truth.corners {
            found += cornerProblems(corners, in: truth.frameSize).map { "frame \(corners.frame): \($0)" }
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

    private func cornerProblems(
        _ corners: GroundTruth.Corners,
        in size: GroundTruth.Size
    ) -> [String] {
        guard corners.points.count == 4 else { return ["\(corners.points.count) corners, need 4"] }
        var found: [String] = []
        if !corners.points.allSatisfy({ $0.isInside(size) }) {
            found.append("a corner lies outside the frame")
        }
        if !corners.points.isConvexClockwise {
            found.append("corners are not ordered far-left, far-right, near-right, near-left")
        }
        return found
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

private extension [GroundTruth.Point] {
    var isConvexClockwise: Bool {
        indices.allSatisfy { index in
            let a = self[index]
            let b = self[(index + 1) % count]
            let c = self[(index + 2) % count]
            return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) > 0
        }
    }
}

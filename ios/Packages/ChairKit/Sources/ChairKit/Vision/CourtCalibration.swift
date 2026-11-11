//
//  CourtCalibration.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import Foundation

public struct CalibrationQuality: Codable, Equatable, Sendable {
    public let sidelineError: Double?
    public let baselineError: Double?
    public let reprojectionError: Double

    public init(
        sidelineError: Double?,
        baselineError: Double?,
        reprojectionError: Double
    ) {
        self.sidelineError = sidelineError
        self.baselineError = baselineError
        self.reprojectionError = reprojectionError
    }

    public init(
        homography: Homography,
        keypoints: [CourtKeypoint: CGPoint],
        frameSize: CGSize
    ) {
        let half = CourtDimensions.halfLength
        let doubles = CourtDimensions.halfDoublesWidth
        let singles = CourtDimensions.halfSinglesWidth
        let sidelines = [-doubles, doubles].flatMap { x in
            [-half, -half / 2, 0, half / 2, half].map { CourtPoint(x: x, y: $0) }
        }
        let baselines = [-half, half].flatMap { y in
            [-doubles, -singles, 0, singles, doubles].map { CourtPoint(x: $0, y: y) }
        }
        self.init(
            sidelineError: Self.worst(sidelines, homography: homography, frameSize: frameSize),
            baselineError: Self.worst(baselines, homography: homography, frameSize: frameSize),
            reprojectionError: homography.reprojectionError(keypoints)
        )
    }

    public static func centimetresPerPixel(
        at court: CourtPoint,
        homography: Homography
    ) -> Double? {
        let centre = homography.toPixel(court)
        let offsets = [CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: -1)]
        let distances = offsets.compactMap { offset in
            homography.toCourt(CGPoint(x: centre.x + offset.x, y: centre.y + offset.y)).map { $0.distance(to: court) }
        }
        guard distances.count == offsets.count else { return nil }
        return distances.max().map { $0 * 100 }
    }

    private static func worst(
        _ points: [CourtPoint],
        homography: Homography,
        frameSize: CGSize
    ) -> Double? {
        let frame = CGRect(origin: .zero, size: frameSize)
        return points
            .filter { homography.toCourt(homography.toPixel($0)) != nil && frame.contains(homography.toPixel($0)) }
            .compactMap { centimetresPerPixel(at: $0, homography: homography) }
            .max()
    }
}

public struct CourtCalibration: Codable, Sendable {
    private struct Mark: Codable {
        let keypoint: CourtKeypoint
        let x: Double
        let y: Double
    }

    private enum CodingKeys: String, CodingKey {
        case keypoints, placement, lens, frameWidth, frameHeight, intrinsicsID, quality, date
    }

    public let keypoints: [CourtKeypoint: CGPoint]
    public let placement: CameraPlacement
    public let lens: CaptureLens
    public let frameSize: CGSize
    public let intrinsicsID: String?
    public let quality: CalibrationQuality
    public let date: Date
    public let homography: Homography

    public init?(
        keypoints: [CourtKeypoint: CGPoint],
        placement: CameraPlacement,
        lens: CaptureLens = .ultraWide,
        frameSize: CGSize,
        intrinsicsID: String? = nil,
        date: Date
    ) {
        guard let homography = Homography(keypoints) else { return nil }
        self.keypoints = keypoints
        self.placement = placement
        self.lens = lens
        self.frameSize = frameSize
        self.intrinsicsID = intrinsicsID
        self.date = date
        self.homography = homography
        quality = CalibrationQuality(homography: homography, keypoints: keypoints, frameSize: frameSize)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let marks = try container.decode([Mark].self, forKey: .keypoints)
        keypoints = Dictionary(marks.map { ($0.keypoint, CGPoint(x: $0.x, y: $0.y)) }) { first, _ in first }
        placement = try container.decode(CameraPlacement.self, forKey: .placement)
        lens = try container.decode(CaptureLens.self, forKey: .lens)
        frameSize = try CGSize(
            width: container.decode(Double.self, forKey: .frameWidth),
            height: container.decode(Double.self, forKey: .frameHeight)
        )
        intrinsicsID = try container.decodeIfPresent(String.self, forKey: .intrinsicsID)
        quality = try container.decode(CalibrationQuality.self, forKey: .quality)
        date = try container.decode(Date.self, forKey: .date)
        guard let homography = Homography(keypoints) else {
            throw DecodingError.dataCorruptedError(
                forKey: .keypoints,
                in: container,
                debugDescription: "Keypoints do not define a homography"
            )
        }
        self.homography = homography
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let marks = CourtKeypoint.all.compactMap { keypoint in
            keypoints[keypoint].map { Mark(keypoint: keypoint, x: Double($0.x), y: Double($0.y)) }
        }
        try container.encode(marks, forKey: .keypoints)
        try container.encode(placement, forKey: .placement)
        try container.encode(lens, forKey: .lens)
        try container.encode(Double(frameSize.width), forKey: .frameWidth)
        try container.encode(Double(frameSize.height), forKey: .frameHeight)
        try container.encodeIfPresent(intrinsicsID, forKey: .intrinsicsID)
        try container.encode(quality, forKey: .quality)
        try container.encode(date, forKey: .date)
    }
}

extension CourtCalibration: Equatable {
    public static func == (
        lhs: CourtCalibration,
        rhs: CourtCalibration
    ) -> Bool {
        lhs.keypoints == rhs.keypoints
            && lhs.placement == rhs.placement
            && lhs.lens == rhs.lens
            && lhs.frameSize == rhs.frameSize
            && lhs.intrinsicsID == rhs.intrinsicsID
            && lhs.quality == rhs.quality
            && lhs.date == rhs.date
    }
}

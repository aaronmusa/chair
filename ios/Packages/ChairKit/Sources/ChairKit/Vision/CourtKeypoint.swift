//
//  CourtKeypoint.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation

public struct CourtKeypoint: Hashable, Sendable, CustomStringConvertible {
    public enum Across: String, CaseIterable, Sendable {
        case doublesLeft, singlesLeft, centre, singlesRight, doublesRight

        public var x: Double {
            switch self {
            case .doublesLeft: -CourtDimensions.halfDoublesWidth
            case .singlesLeft: -CourtDimensions.halfSinglesWidth
            case .centre: 0
            case .singlesRight: CourtDimensions.halfSinglesWidth
            case .doublesRight: CourtDimensions.halfDoublesWidth
            }
        }
    }

    public enum Along: String, CaseIterable, Sendable {
        case farBaseline, farService, nearService, nearBaseline

        public var y: Double {
            switch self {
            case .farBaseline: CourtDimensions.halfLength
            case .farService: CourtDimensions.serviceLineFromNet
            case .nearService: -CourtDimensions.serviceLineFromNet
            case .nearBaseline: -CourtDimensions.halfLength
            }
        }

        var isBaseline: Bool {
            self == .farBaseline || self == .nearBaseline
        }
    }

    public let across: Across
    public let along: Along

    public init?(
        _ across: Across,
        _ along: Along
    ) {
        let valid = along.isBaseline ? across != .centre : across != .doublesLeft && across != .doublesRight
        guard valid else { return nil }
        self.across = across
        self.along = along
    }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "-").map(String.init)
        guard parts.count == 2, let across = Across(rawValue: parts[0]), let along = Along(rawValue: parts[1]) else {
            return nil
        }
        self.init(across, along)
    }

    public static let all: [CourtKeypoint] = Along.allCases.flatMap { along in
        Across.allCases.compactMap { CourtKeypoint($0, along) }
    }

    public var rawValue: String {
        "\(across.rawValue)-\(along.rawValue)"
    }

    public var description: String {
        rawValue
    }

    public var court: CourtPoint {
        CourtPoint(x: across.x, y: along.y)
    }
}

extension CourtKeypoint: Codable {
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let keypoint = CourtKeypoint(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown keypoint \(raw)"))
        }
        self = keypoint
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum CameraPlacement: String, Codable, CaseIterable, Sendable {
    case netPost
    case baseline
    case chair

    public var keypoints: [CourtKeypoint] {
        switch self {
        case .netPost, .chair:
            [
                CourtKeypoint(.doublesRight, .farBaseline),
                CourtKeypoint(.singlesRight, .farBaseline),
                CourtKeypoint(.singlesRight, .farService),
                CourtKeypoint(.centre, .farService),
                CourtKeypoint(.centre, .nearService),
                CourtKeypoint(.singlesRight, .nearService),
                CourtKeypoint(.singlesRight, .nearBaseline),
                CourtKeypoint(.doublesRight, .nearBaseline),
            ].compactMap(\.self)
        case .baseline:
            [
                CourtKeypoint(.doublesLeft, .farBaseline),
                CourtKeypoint(.doublesRight, .farBaseline),
                CourtKeypoint(.doublesRight, .nearBaseline),
                CourtKeypoint(.doublesLeft, .nearBaseline),
            ].compactMap(\.self)
        }
    }
}

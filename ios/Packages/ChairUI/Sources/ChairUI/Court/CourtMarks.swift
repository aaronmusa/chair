//
//  CourtMarks.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

public enum ServiceCourt: Sendable {
    case deuce
    case ad
}

public extension CourtPoint {
    static func behindBaseline(
        _ side: CourtSide,
        on serviceCourt: ServiceCourt,
        by metres: Double,
        fromCentre offset: Double = 1
    ) -> CourtPoint {
        let towardsDeuce: Double = side == .near ? 1 : -1
        let across = serviceCourt == .deuce ? towardsDeuce * offset : -towardsDeuce * offset
        let along = CourtDimensions.halfLength + metres
        return CourtPoint(x: across, y: side == .near ? -along : along)
    }
}

public struct PlayerMarker: Identifiable, Sendable {
    public enum Role: Sendable {
        case server
        case receiver
        case partner
    }

    public let id: String
    public let side: CourtSide
    public let position: CourtPoint
    public let role: Role

    public init(
        id: String,
        side: CourtSide,
        position: CourtPoint,
        role: Role
    ) {
        self.id = id
        self.side = side
        self.position = position
        self.role = role
    }
}

public struct CourtZone: Identifiable, Sendable {
    public let id: String
    public let from: CourtPoint
    public let to: CourtPoint

    public init(
        id: String,
        from: CourtPoint,
        to: CourtPoint
    ) {
        self.id = id
        self.from = from
        self.to = to
    }
}

public struct BallMark: Sendable {
    public enum Call: Sendable {
        case `in`
        case out
    }

    public let point: CourtPoint
    public let call: Call

    public init(
        _ point: CourtPoint,
        call: Call
    ) {
        self.point = point
        self.call = call
    }
}

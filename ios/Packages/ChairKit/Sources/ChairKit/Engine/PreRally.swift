//
//  PreRally.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public enum ServeNumber: String, Codable, Sendable {
    case first
    case second
}

public struct PreRally: Codable, Equatable, Sendable {
    public let server: PlayerSlot
    public let serverNameIndex: Int
    public let receiver: PlayerSlot
    public let serverCourtSide: CourtSide
    public let ends: [Side: CourtEnd]
    public let serve: ServeNumber
}

public struct EngineOutput: Codable, Equatable, Sendable {
    public let state: MatchState
    public let announcements: [Announcement]
    public let preRally: PreRally

    public init(
        state: MatchState,
        announcements: [Announcement]
    ) {
        self.state = state
        self.announcements = announcements
        preRally = state.preRally
    }
}

public extension MatchState {
    var preRally: PreRally {
        let slots: [PlayerSlot] = doublesOrder == nil ? [.a1, .b1] : PlayerSlot.allCases
        return PreRally(
            server: server,
            serverNameIndex: slots.firstIndex(of: server) ?? 0,
            receiver: receiver,
            serverCourtSide: serverCourtSide,
            ends: ends,
            serve: faultCount == 0 ? .first : .second
        )
    }
}

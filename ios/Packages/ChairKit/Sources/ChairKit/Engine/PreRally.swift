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
        PreRally(
            server: server,
            serverNameIndex: server.nameIndex(doubles: doublesOrder != nil),
            receiver: receiver,
            serverCourtSide: serverCourtSide,
            ends: ends,
            serve: faultCount == 0 ? .first : .second
        )
    }
}

extension PlayerSlot {
    func nameIndex(doubles: Bool) -> Int {
        let team = side == .a ? 0 : 1
        let member = self == .a2 || self == .b2 ? 1 : 0
        return doubles ? team * 2 + member : team
    }
}

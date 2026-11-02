//
//  WatchMessage.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

public enum WatchMessage: Codable, Equatable, Sendable {
    case input(WatchInput)
    case requestState
    case endWorkout
    case openNewMatch
    case state(WatchState)
    case idle(lastResult: String?)
    case ack(inputID: UUID)
    case refused(inputID: UUID)
    case announcement(text: String)
    case matchEnded
}

public enum WatchPhase: String, Codable, Sendable {
    case waiting
    case getSet
    case rally
    case complete
}

public struct WatchInput: Codable, Equatable, Sendable, Identifiable {
    public enum Action: Codable, Equatable, Sendable {
        case point(Side)
        case fault
        case `let`
        case undo
        case swapEnds
    }

    public let id: UUID
    public let at: Date
    public let matchID: UUID?
    public let action: Action

    public init(
        _ action: Action,
        matchID: UUID? = nil,
        id: UUID = UUID(),
        at: Date = Date()
    ) {
        self.id = id
        self.at = at
        self.matchID = matchID
        self.action = action
    }
}

public struct WatchState: Codable, Equatable, Sendable {
    public var matchID: UUID
    public var names: [PlayerSlot: String]
    public var mySlot: PlayerSlot
    public var score: ScoreSnapshot
    public var serverCourtSide: CourtSide
    public var serve: ServeNumber
    public var phase: WatchPhase

    public init(
        matchID: UUID,
        names: [PlayerSlot: String],
        mySlot: PlayerSlot,
        score: ScoreSnapshot,
        serverCourtSide: CourtSide,
        serve: ServeNumber,
        phase: WatchPhase
    ) {
        self.matchID = matchID
        self.names = names
        self.mySlot = mySlot
        self.score = score
        self.serverCourtSide = serverCourtSide
        self.serve = serve
        self.phase = phase
    }

    public var mySide: Side {
        mySlot.side
    }

    public var server: PlayerSlot {
        score.server
    }
}

public struct WatchEnvelope: Codable, Equatable, Sendable {
    public static let protocolVersion = 1

    public let protocolVersion: Int
    public let message: WatchMessage?

    public init(_ message: WatchMessage) {
        protocolVersion = Self.protocolVersion
        self.message = message
    }

    public var data: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public static func decode(_ data: Data) -> Received? {
        guard let version = try? JSONDecoder().decode(Version.self, from: data) else { return nil }
        guard version.protocolVersion == protocolVersion else { return .versionMismatch(version.protocolVersion) }
        guard let message = try? JSONDecoder().decode(WatchEnvelope.self, from: data).message else { return nil }
        return .message(message)
    }

    public enum Received: Equatable, Sendable {
        case message(WatchMessage)
        case versionMismatch(Int)
    }

    private struct Version: Decodable {
        let protocolVersion: Int
    }
}

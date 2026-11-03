//
//  GetSetPresentation.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import ChairKit
import ChairUI

struct GetSetPresentation {
    let serverName: String
    let serveLabel: String
    private(set) var strip: String
    let accessibilitySentence: String
    let markers: [PlayerMarker]
    let isDoubles: Bool
    let receivingSide: Side
    let canSwapServer: Bool
    let canSwapSides: Bool

    init(
        state: MatchState,
        names: [PlayerSlot: String],
        announcements: [Announcement] = []
    ) {
        let preRally = state.preRally
        let formatter = AnnouncementFormatter(names: PlayerNames(names, doubles: state.doublesOrder != nil))
        let score = formatter.score(state)
        let side = preRally.serverCourtSide == .deuce ? "deuce" : "ad"
        let serve = preRally.serve == .first ? "1st serve" : "2nd serve"
        let spokenServe = preRally.serve == .first ? "first serve" : "second serve"

        serverName = Self.name(preRally.server, in: names)
        serveLabel = "\(serverName) serves · \(side) side · \(serve)"
        strip = announcements.isEmpty ? score : formatter.text(announcements, after: state)
        accessibilitySentence = "\(serverName) serves from the \(side) side, \(spokenServe). \(score)"
        markers = Self.markers(preRally, names: names, doubles: state.doublesOrder != nil)
        isDoubles = state.doublesOrder != nil
        receivingSide = preRally.receiver.side
        canSwapServer = !Self.isOver(state) && Self.isBeforeFirstPoint(of: state)
        canSwapSides = !Self.isOver(state)
    }

    func noted(_ note: String?) -> GetSetPresentation {
        guard let note else { return self }
        var noted = self
        noted.strip = "\(strip) · \(note)"
        return noted
    }

    var canSwapReceivers: Bool {
        isDoubles && canSwapServer
    }

    private static func isOver(_ state: MatchState) -> Bool {
        if case .complete = state.phase {
            return true
        }
        return false
    }

    private static func isBeforeFirstPoint(of state: MatchState) -> Bool {
        state.currentSet == SetScore(a: 0, b: 0) && state.currentGame == .loveAll && state.faultCount == 0
    }

    private static func name(
        _ slot: PlayerSlot,
        in names: [PlayerSlot: String]
    ) -> String {
        names[slot] ?? "Player \(slot.rawValue)"
    }

    private static func markers(
        _ preRally: PreRally,
        names: [PlayerSlot: String],
        doubles: Bool
    ) -> [PlayerMarker] {
        let serverEnd = preRally.ends[preRally.server.side] ?? .near
        let receiverEnd = preRally.ends[preRally.receiver.side] ?? .far
        let courtSide = preRally.serverCourtSide
        let otherSide: CourtSide = courtSide == .deuce ? .ad : .deuce
        var markers = [
            PlayerMarker(
                id: name(preRally.server, in: names),
                side: serverEnd,
                position: .behindBaseline(serverEnd, on: courtSide, by: 1),
                role: .server
            ),
            PlayerMarker(
                id: name(preRally.receiver, in: names),
                side: receiverEnd,
                position: .behindBaseline(receiverEnd, on: courtSide, by: 1),
                role: .receiver
            ),
        ]
        guard doubles else { return markers }
        let halfLength = CourtDimensions.halfLength
        markers.append(PlayerMarker(
            id: name(partner(of: preRally.server), in: names),
            side: serverEnd,
            position: .behindBaseline(serverEnd, on: otherSide, by: 3 - halfLength, fromCentre: 2.5),
            role: .partner
        ))
        markers.append(PlayerMarker(
            id: name(partner(of: preRally.receiver), in: names),
            side: receiverEnd,
            position: .behindBaseline(receiverEnd, on: otherSide, by: CourtDimensions.serviceLineFromNet - halfLength, fromCentre: 2.5),
            role: .partner
        ))
        return markers
    }

    private static func partner(of slot: PlayerSlot) -> PlayerSlot {
        switch slot {
        case .a1: .a2
        case .a2: .a1
        case .b1: .b2
        case .b2: .b1
        }
    }
}

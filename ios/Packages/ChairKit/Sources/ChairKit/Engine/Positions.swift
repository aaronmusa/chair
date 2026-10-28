//
//  Positions.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public struct Positions: Codable, Equatable, Sendable {
    public let server: PlayerSlot
    public let serverCourtSide: CourtSide
    public let receiver: PlayerSlot
    public let serverPartner: PlayerSlot?
    public let receiverPartner: PlayerSlot?
    public let ends: [PlayerSlot: CourtEnd]
}

public extension MatchState {
    var positions: Positions {
        let isDoubles = doublesOrder != nil
        let slots: [PlayerSlot] = isDoubles ? PlayerSlot.allCases : [.a1, .b1]
        let slotEnds = ends.flatMap { side, end in slots.filter { $0.side == side }.map { ($0, end) } }
        return Positions(
            server: server,
            serverCourtSide: serverCourtSide,
            receiver: receiver,
            serverPartner: isDoubles ? server.partner : nil,
            receiverPartner: isDoubles ? receiver.partner : nil,
            ends: Dictionary(uniqueKeysWithValues: slotEnds)
        )
    }
}

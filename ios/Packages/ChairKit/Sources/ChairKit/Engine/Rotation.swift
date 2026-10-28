//
//  Rotation.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

enum Rotation {
    static func nextServer(
        after server: PlayerSlot,
        in state: MatchState
    ) -> PlayerSlot {
        guard let order = state.doublesOrder?.serving, let index = order.firstIndex(of: server) else {
            return server.side == .a ? .b1 : .a1
        }
        return order[(index + 1) % order.count]
    }

    static func receiver(
        serving server: PlayerSlot,
        from side: CourtSide,
        in state: MatchState
    ) -> PlayerSlot {
        let receivingSide = server.side.opponent
        guard let deuceReceiver = state.doublesOrder?.deuceReceivers[receivingSide] else {
            return receivingSide == .a ? .a1 : .b1
        }
        return side == .deuce ? deuceReceiver : deuceReceiver.partner
    }

    static func changeEnds(in state: inout MatchState) {
        state.ends = state.ends.mapValues { $0 == .near ? .far : .near }
    }
}

public extension PlayerSlot {
    var partner: PlayerSlot {
        switch self {
        case .a1: .a2
        case .a2: .a1
        case .b1: .b2
        case .b2: .b1
        }
    }
}

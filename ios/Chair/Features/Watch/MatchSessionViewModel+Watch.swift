//
//  MatchSessionViewModel+Watch.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

import ChairKit

extension MatchSessionViewModel {
    var isLive: Bool {
        phase == .getSet || phase == .rally
    }

    var watchPhase: WatchPhase {
        switch phase {
        case .getSet: .getSet
        case .rally: .rally
        case .finishing, .complete: .complete
        case .loading, .failed: .waiting
        }
    }

    var watchState: WatchState? {
        guard let state, let log else { return nil }
        return WatchState(
            matchID: matchID,
            names: names,
            mySlot: mySlot,
            score: log.snapshot,
            serverCourtSide: state.serverCourtSide,
            serve: state.preRally.serve,
            phase: watchPhase,
            deuceReceiver: state.doublesOrder?.deuceReceivers[mySlot.side],
            winner: state.phase.winner
        )
    }
}

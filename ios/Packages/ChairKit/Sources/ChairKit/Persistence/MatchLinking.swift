//
//  MatchLinking.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

public extension Match {
    func link(
        _ slot: PlayerSlot,
        to userID: UUID,
        at date: Date
    ) {
        guard slot != localUserSlot, let player = players.first(where: { $0.slot == slot }) else { return }
        player.userID = userID
        player.linkStatus = .pending
        player.invitedAt = date
        player.respondedAt = nil
        touch(player, at: date)
    }

    func unlink(
        _ slot: PlayerSlot,
        at date: Date
    ) {
        guard let player = players.first(where: { $0.slot == slot }), player.userID != nil else { return }
        player.userID = nil
        player.linkStatus = .none
        player.invitedAt = nil
        player.respondedAt = nil
        touch(player, at: date)
    }

    private func touch(
        _ player: MatchPlayer,
        at date: Date
    ) {
        player.updatedAt = date
        player.syncState = .pendingUpload
        updatedAt = date
        syncState = .pendingUpload
    }
}

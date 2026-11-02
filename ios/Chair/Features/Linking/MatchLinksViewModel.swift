//
//  MatchLinksViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class MatchLinksViewModel {
    struct Row: Equatable, Identifiable {
        let slot: PlayerSlot
        let name: String
        let status: LinkStatus

        var id: PlayerSlot {
            slot
        }
    }

    var pickerSlot: PlayerSlot?
    var isShowingSignIn = false
    private(set) var rows: [Row] = []
    private(set) var errorMessage: String?

    private let matchID: UUID
    private let repository: any MatchRepository
    private let auth: any AuthService
    private let clock: any ClockProvider

    init(
        matchID: UUID,
        repository: any MatchRepository,
        environment: AppEnvironment
    ) {
        self.matchID = matchID
        self.repository = repository
        auth = environment.auth
        clock = environment.clock
    }

    func watch() async {
        for await _ in repository.observe() {
            reload()
        }
    }

    func reload() {
        guard let match = match() else {
            rows = []
            return
        }
        rows = match.orderedPlayers
            .filter { $0.slot != match.localUserSlot }
            .map { Row(slot: $0.slot, name: $0.name, status: $0.linkStatus) }
    }

    func requestLink(_ slot: PlayerSlot) async {
        if await auth.currentSession() == nil {
            isShowingSignIn = true
        } else {
            pickerSlot = slot
        }
    }

    func link(
        _ slot: PlayerSlot,
        to profile: PublicProfile
    ) {
        pickerSlot = nil
        change { $0.link(slot, to: profile.id, at: clock.now) }
    }

    func unlink(_ slot: PlayerSlot) {
        change { $0.unlink(slot, at: clock.now) }
    }

    private func change(_ edit: (Match) -> Void) {
        guard let match = match() else {
            errorMessage = "Couldn't find this match."
            return
        }
        edit(match)
        do {
            try repository.save(match)
        } catch {
            errorMessage = "Couldn't save the link. Try again."
        }
        reload()
    }

    private func match() -> Match? {
        try? repository.fetch().first { $0.remoteID == matchID }
    }
}

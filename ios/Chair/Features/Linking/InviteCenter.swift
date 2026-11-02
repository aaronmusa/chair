//
//  InviteCenter.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation
import SwiftUI

import ChairKit

@MainActor
@Observable
final class InviteCenter {
    private(set) var invites: [Invite] = []
    private(set) var errorMessage: String?
    var isShowingInvites = false

    private let remote: any InviteRemote
    private let auth: any AuthService
    private let sync: SyncCoordinator?

    init(
        remote: any InviteRemote,
        auth: any AuthService,
        sync: SyncCoordinator?
    ) {
        self.remote = remote
        self.auth = auth
        self.sync = sync
    }

    var count: Int {
        invites.count
    }

    var bannerText: String {
        count == 1 ? "1 match invite" : "\(count) match invites"
    }

    func refresh() async {
        guard await auth.currentSession() != nil else {
            invites = []
            return
        }
        if let fetched = try? await remote.pendingInvites() {
            invites = fetched
        }
    }

    func accept(_ invite: Invite) async {
        await respond(to: invite, accept: true)
    }

    func decline(_ invite: Invite) async {
        await respond(to: invite, accept: false)
    }

    private func respond(
        to invite: Invite,
        accept: Bool
    ) async {
        do {
            try await remote.respond(to: invite.matchID, accept: accept)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't answer the invite. Check your connection and try again."
            return
        }
        await refresh()
        await sync?.syncNow()
    }
}

extension EnvironmentValues {
    @Entry var inviteCenter: InviteCenter?
}

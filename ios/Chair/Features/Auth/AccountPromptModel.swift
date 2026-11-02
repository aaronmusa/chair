//
//  AccountPromptModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class AccountPromptModel {
    private(set) var prompt: AccountPrompt?
    private(set) var errorMessage: String?

    private let auth: any AuthService
    private let migration: AccountMigration
    private let sync: SyncCoordinator?
    private var userID: UUID?

    init(
        auth: any AuthService,
        migration: AccountMigration,
        sync: SyncCoordinator?
    ) {
        self.auth = auth
        self.migration = migration
        self.sync = sync
    }

    var title: String {
        switch prompt {
        case let .keepLocal(count): count == 1 ? "Keep your match?" : "Keep your \(count) matches?"
        case .replaceLocal: "Replace local data with the new account?"
        case nil: ""
        }
    }

    var message: String {
        switch prompt {
        case .keepLocal: "They were scored on this device before you signed in. Keep them to add them to your account."
        case .replaceLocal: "Matches on this device belong to another account. Replacing removes them from this device."
        case nil: ""
        }
    }

    func watch() async {
        for await session in await auth.sessionStream {
            check(session)
        }
    }

    func check(_ session: AuthSession?) {
        userID = session?.userID
        guard let userID else {
            prompt = nil
            return
        }
        prompt = try? migration.pendingPrompt(for: userID)
        if prompt == nil {
            syncNow()
        }
    }

    func keep() {
        guard let userID else { return }
        migration.keep(for: userID)
        finish()
    }

    func discard() {
        guard let userID else { return }
        perform { try migration.discard(for: userID) }
    }

    func replace() {
        guard let userID else { return }
        perform { try migration.replace(for: userID) }
    }

    func cancelReplace() async {
        prompt = nil
        try? await auth.signOut()
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
            finish()
        } catch {
            errorMessage = "Couldn't update matches on this device."
            prompt = nil
        }
    }

    private func finish() {
        prompt = nil
        syncNow()
    }

    private func syncNow() {
        guard let sync else { return }
        Task { await sync.syncNow() }
    }
}

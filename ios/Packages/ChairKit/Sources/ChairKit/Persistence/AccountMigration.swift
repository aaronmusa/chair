//
//  AccountMigration.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

public enum AccountPrompt: Equatable, Sendable {
    case keepLocal(count: Int)
    case replaceLocal
}

public protocol AccountStore: AnyObject {
    var lastUserID: UUID? { get set }
}

public final class UserDefaultsAccountStore: AccountStore {
    private static let key = "chair.account.lastUserID"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var lastUserID: UUID? {
        get { defaults.string(forKey: Self.key).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Self.key) }
    }
}

@MainActor
public final class AccountMigration {
    private let repository: SyncingMatchRepository
    private let store: any AccountStore
    private let courts: SyncingSavedCourtRepository?

    public init(
        repository: SyncingMatchRepository,
        store: any AccountStore,
        courts: SyncingSavedCourtRepository? = nil
    ) {
        self.repository = repository
        self.store = store
        self.courts = courts
    }

    public func pendingPrompt(for userID: UUID) throws -> AccountPrompt? {
        if let last = store.lastUserID, last != userID, try repository.hasLocalMatches() {
            return .replaceLocal
        }
        let unclaimed = try repository.unclaimedMatches().count
        if store.lastUserID != userID, unclaimed > 0 {
            return .keepLocal(count: unclaimed)
        }
        store.lastUserID = userID
        return nil
    }

    public func keep(for userID: UUID) {
        store.lastUserID = userID
    }

    public func discard(for userID: UUID) throws {
        try repository.discardUnclaimed()
        store.lastUserID = userID
    }

    public func replace(for userID: UUID) throws {
        try repository.clearLocal()
        try courts?.clearLocal()
        store.lastUserID = userID
    }
}

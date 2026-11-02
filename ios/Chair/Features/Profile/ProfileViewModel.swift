//
//  ProfileViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class ProfileViewModel {
    enum HandleStatus: Equatable {
        case unchanged
        case invalid
        case checking
        case available
        case taken
        case unknown

        var text: String? {
            switch self {
            case .unchanged: nil
            case .invalid: "3–20 lowercase letters, numbers or _"
            case .checking: "Checking…"
            case .available: "Available"
            case .taken: "Taken"
            case .unknown: "Couldn't check. Try again."
            }
        }
    }

    enum DeleteStep: Equatable {
        case confirm
        case final
    }

    var handle = "" {
        didSet { handleDidChange() }
    }

    var displayName = ""
    var homeCourt = ""
    var hand: Hand?
    var level: Level?
    var deleteStep: DeleteStep?
    var errorMessage: String?
    private(set) var handleStatus = HandleStatus.unchanged
    private(set) var original: ProfileRecord?
    private(set) var isWorking = false

    private let auth: any AuthService
    private let remote: (any ProfileRemote)?
    private let profiles: ProfileRepository
    private let matches: (any MatchRepository)?
    private let accountStore: any AccountStore
    private let debounce: Duration
    private let onSignedOut: () -> Void
    private var check: Task<Void, Never>?

    init(
        environment: AppEnvironment,
        profiles: ProfileRepository,
        matches: (any MatchRepository)?,
        accountStore: any AccountStore = UserDefaultsAccountStore(),
        debounce: Duration = .milliseconds(400),
        onSignedOut: @escaping () -> Void
    ) {
        auth = environment.auth
        remote = environment.profileRemote
        self.profiles = profiles
        self.matches = matches
        self.accountStore = accountStore
        self.debounce = debounce
        self.onSignedOut = onSignedOut
    }

    var canSave: Bool {
        guard original != nil, !isWorking else { return false }
        let nameLength = displayName.trimmingCharacters(in: .whitespaces).count
        return [.unchanged, .available].contains(handleStatus) && (1 ... 40).contains(nameLength) && draft != original
    }

    func load() async {
        show(try? profiles.current())
        try? await profiles.sync()
        show(try? profiles.current())
    }

    func save() async {
        guard let draft, canSave else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try profiles.save(draft)
        } catch {
            errorMessage = "Couldn't save your profile."
            return
        }
        original = draft
        handleStatus = .unchanged
        try? await profiles.sync()
    }

    func signOut() async {
        do {
            try await auth.signOut()
            onSignedOut()
        } catch {
            errorMessage = "Couldn't sign out. Try again."
        }
    }

    func requestDelete() {
        deleteStep = .confirm
    }

    func confirmDelete() {
        deleteStep = .final
    }

    func deleteAccount() async {
        deleteStep = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.deleteAccount()
        } catch {
            errorMessage = "Couldn't delete your account. Check your connection and try again."
            return
        }
        try? matches?.clearLocal()
        try? profiles.clear()
        accountStore.lastUserID = nil
        onSignedOut()
    }

    private var draft: ProfileRecord? {
        guard let original else { return nil }
        return ProfileRecord(
            id: original.id,
            handle: handle.trimmingCharacters(in: .whitespaces).lowercased(),
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            homeCourt: homeCourt.trimmingCharacters(in: .whitespaces).isEmpty ? nil : homeCourt.trimmingCharacters(in: .whitespaces),
            hand: hand,
            level: level
        )
    }

    private func show(_ profile: ProfileRecord?) {
        guard let profile else { return }
        original = profile
        handle = profile.handle
        displayName = profile.displayName
        homeCourt = profile.homeCourt ?? ""
        hand = profile.hand
        level = profile.level
        handleStatus = .unchanged
    }

    private func handleDidChange() {
        check?.cancel()
        let candidate = handle.trimmingCharacters(in: .whitespaces).lowercased()
        if candidate == original?.handle.lowercased() {
            handleStatus = .unchanged
            return
        }
        guard candidate.wholeMatch(of: /[a-z0-9_]{3,20}/) != nil else {
            handleStatus = .invalid
            return
        }
        handleStatus = .checking
        check = Task { [weak self, debounce, remote] in
            try? await Task.sleep(for: debounce)
            guard self != nil, !Task.isCancelled else { return }
            let available = try? await remote?.handleAvailable(candidate)
            guard let self, !Task.isCancelled else { return }
            handleStatus = available.map { $0 ? .available : .taken } ?? .unknown
        }
    }
}

//
//  OpponentPickerViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class OpponentPickerViewModel {
    var query = "" {
        didSet { queryDidChange() }
    }

    private(set) var results: [PublicProfile] = []
    private(set) var message: String?

    private let remote: (any ProfileRemote)?
    private let debounce: Duration
    private let onPick: (PublicProfile) -> Void
    private var search: Task<Void, Never>?

    init(
        environment: AppEnvironment,
        debounce: Duration = .milliseconds(300),
        onPick: @escaping (PublicProfile) -> Void
    ) {
        remote = environment.profileRemote
        self.debounce = debounce
        self.onPick = onPick
    }

    func pick(_ profile: PublicProfile) {
        onPick(profile)
    }

    func pick(handle: String) async {
        guard let profile = try? await remote?.publicProfile(handle: handle) else {
            message = "No player with the handle @\(handle)"
            return
        }
        onPick(profile)
    }

    func scanned(_ payload: String) async {
        guard let url = URL(string: payload), let handle = AppRouter.userHandle(in: url) else {
            message = "That QR code isn't a Chair player"
            return
        }
        await pick(handle: handle)
    }

    private func queryDidChange() {
        search?.cancel()
        let prefix = query.trimmingCharacters(in: .whitespaces)
        message = nil
        guard !prefix.isEmpty else {
            results = []
            return
        }
        search = Task { [weak self, debounce, remote] in
            try? await Task.sleep(for: debounce)
            guard self != nil, !Task.isCancelled else { return }
            let found = try? await remote?.search(prefix)
            guard let self, !Task.isCancelled else { return }
            results = found ?? []
            message = found == nil ? "Couldn't search. Check your connection." : found?.isEmpty == true ? "No players found" : nil
        }
    }
}

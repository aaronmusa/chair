//
//  PublicProfileViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class PublicProfileViewModel {
    let handle: String
    private(set) var profile: PublicProfile?
    private(set) var matchesWithYou = 0
    private(set) var isMissing = false

    private let remote: (any ProfileRemote)?

    init(
        handle: String,
        environment: AppEnvironment
    ) {
        self.handle = handle
        remote = environment.profileRemote
    }

    func load() async {
        guard let remote else {
            isMissing = true
            return
        }
        do {
            profile = try await remote.publicProfile(handle: handle)
            isMissing = profile == nil
            if let profile {
                matchesWithYou = try await remote.linkedMatchCount(with: profile.id)
            }
        } catch {
            isMissing = profile == nil
        }
    }
}

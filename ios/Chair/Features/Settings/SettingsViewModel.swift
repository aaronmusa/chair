//
//  SettingsViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class SettingsViewModel {
    static let privacyURL = URL(string: "https://aaronmusa.github.io/chair-legal/privacy/")!
    static let supportURL = URL(string: "https://aaronmusa.github.io/chair-legal/support/")!

    var defaults: MatchDefaults {
        didSet { store.save(defaults) }
    }

    private(set) var accountStatus = "Not signed in"
    private(set) var isSignedIn = false
    var isShowingSignIn = false
    var isShowingProfile = false
    let version: String
    let build: String
    let environment: AppEnvironment

    private let store: any MatchDefaultsStore
    private let auth: any AuthService

    init(
        environment: AppEnvironment,
        info: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) {
        self.environment = environment
        store = environment.matchDefaults
        auth = environment.auth
        defaults = environment.matchDefaults.load()
        version = info["CFBundleShortVersionString"] as? String ?? "–"
        build = info["CFBundleVersion"] as? String ?? "–"
    }

    func refreshAccount() async {
        await show(auth.currentSession())
    }

    func watchAccount() async {
        for await session in await auth.sessionStream {
            await show(session)
        }
    }

    func showAccount() {
        if isSignedIn {
            isShowingProfile = true
        } else {
            isShowingSignIn = true
        }
    }

    func makeProfileViewModel(
        profiles: ProfileRepository,
        matches: (any MatchRepository)?,
        courts: (any SavedCourtRepository)?
    ) -> ProfileViewModel {
        ProfileViewModel(
            environment: environment,
            profiles: profiles,
            matches: matches,
            courts: courts,
            onSignedOut: handleSignedOut()
        )
    }

    private func handleSignedOut() -> () -> Void {
        { [weak self] in self?.isShowingProfile = false }
    }

    func makeSignInViewModel() -> SignInViewModel {
        SignInViewModel(environment: environment, onFinish: handleSignInFinished())
    }

    private func handleSignInFinished() -> () -> Void {
        { [weak self] in self?.isShowingSignIn = false }
    }

    private func show(_ session: AuthSession?) async {
        guard session != nil else {
            isSignedIn = false
            accountStatus = "Not signed in"
            return
        }
        isSignedIn = true
        let profile = try? await environment.profileRemote?.ownProfile()
        accountStatus = profile.map { "@\($0.handle)" } ?? "Signed in"
    }
}

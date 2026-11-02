//
//  SignInViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import AuthenticationServices
import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class SignInViewModel {
    enum Reason {
        case account
        case linkOpponent
        case saveMatch

        var text: String {
            switch self {
            case .account, .linkOpponent: "Sign in to sync matches and link opponents"
            case .saveMatch: "Save this match to your account"
            }
        }
    }

    let reason: Reason
    private(set) var isSigningIn = false
    private(set) var inlineError: String?
    var alertMessage: String?

    private let auth: any AuthService
    private let profiles: (any ProfileRemote)?
    private let onFinish: () -> Void

    init(
        environment: AppEnvironment,
        reason: Reason = .account,
        onFinish: @escaping () -> Void
    ) {
        auth = environment.auth
        profiles = environment.profileRemote
        self.reason = reason
        self.onFinish = onFinish
    }

    func complete(_ result: Result<AppleCredential, any Error>) async {
        switch result {
        case let .success(credential):
            await signIn(with: credential)
        case let .failure(error):
            show(error)
        }
    }

    func continueWithoutAccount() {
        onFinish()
    }

    private func signIn(with credential: AppleCredential) async {
        isSigningIn = true
        inlineError = nil
        defer { isSigningIn = false }
        do {
            _ = try await auth.signInWithApple(idToken: credential.idToken, nonce: credential.nonce)
        } catch {
            show(error)
            return
        }
        if let name = credential.fullName {
            try? await profiles?.claimDisplayName(name)
        }
        onFinish()
    }

    private func show(_ error: any Error) {
        if let apple = error as? ASAuthorizationError {
            guard apple.code != .canceled else { return }
            alertMessage = "Sign in with Apple failed (code \(apple.code.rawValue))."
        } else if error is URLError {
            inlineError = "Couldn't reach Chair. Check your connection and try again."
        } else {
            alertMessage = "Sign in failed. \(error.localizedDescription)"
        }
    }
}

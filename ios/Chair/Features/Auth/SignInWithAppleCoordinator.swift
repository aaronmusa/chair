//
//  SignInWithAppleCoordinator.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import AuthenticationServices
import CryptoKit
import Foundation

struct AppleCredential: Equatable {
    let idToken: String
    let nonce: String
    let fullName: String?
}

enum AppleSignInError: Error, Equatable {
    case missingToken
}

@MainActor
final class SignInWithAppleCoordinator {
    private var nonce: String?

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        self.nonce = nonce
        request.requestedScopes = [.fullName]
        request.nonce = Self.sha256(nonce)
    }

    func credential(from result: Result<ASAuthorization, any Error>) -> Result<AppleCredential, any Error> {
        result.flatMap { authorization in
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = apple.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce else {
                return .failure(AppleSignInError.missingToken)
            }
            let name = apple.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            return .success(AppleCredential(idToken: idToken, nonce: nonce, fullName: name?.isEmpty == true ? nil : name))
        }
    }

    static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0 ..< length).map { _ in characters.randomElement(using: &generator)! })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

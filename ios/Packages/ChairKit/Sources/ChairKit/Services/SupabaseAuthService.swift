//
//  SupabaseAuthService.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

import Supabase

public struct SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func currentSession() async -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return AuthSession(userID: session.user.id, accessToken: session.accessToken)
    }

    public func signInWithApple(
        idToken: String,
        nonce: String
    ) async throws -> AuthSession {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        return AuthSession(userID: session.user.id, accessToken: session.accessToken)
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    public func deleteAccount() async throws {
        throw AuthError.accountDeletionUnavailable
    }
}

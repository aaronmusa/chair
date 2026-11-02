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

    public var sessionStream: AsyncStream<AuthSession?> {
        let changes = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await change in changes {
                    continuation.yield(change.session.map { AuthSession(userID: $0.user.id, accessToken: $0.accessToken) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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
        try await client.functions.invoke("delete-account", options: FunctionInvokeOptions(method: .post))
        try await client.auth.signOut(scope: .local)
    }

    #if DEBUG
        public func signIn(
            email: String,
            password: String
        ) async throws -> AuthSession {
            let session = try await client.auth.signIn(email: email, password: password)
            return AuthSession(userID: session.user.id, accessToken: session.accessToken)
        }
    #endif
}

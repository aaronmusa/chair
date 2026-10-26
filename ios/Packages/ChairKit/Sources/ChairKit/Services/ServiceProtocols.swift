//
//  ServiceProtocols.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

public struct AuthSession: Equatable, Sendable {
    public let userID: UUID
    public let accessToken: String

    public init(
        userID: UUID,
        accessToken: String
    ) {
        self.userID = userID
        self.accessToken = accessToken
    }
}

public enum AuthError: Error, Equatable, Sendable {
    case notSignedIn
    case accountDeletionUnavailable
}

public protocol AuthService: Sendable {
    func currentSession() async -> AuthSession?
    func signInWithApple(
        idToken: String,
        nonce: String
    ) async throws -> AuthSession
    func signOut() async throws
    func deleteAccount() async throws
}

public enum AudioRoute: String, Sendable {
    case speaker
    case bluetooth
    case headphones
}

public protocol SpeechOutput: Sendable {
    func speak(_ text: String) async
    func stop() async
    func route() async -> AudioRoute
}

public enum SpeechEvent: Equatable, Sendable {
    case heard(String)
    case ended
}

public protocol SpeechInput: Sendable {
    func startListening(grammar: [String]) async throws -> AsyncStream<SpeechEvent>
    func stopListening() async
}

public struct CoachCard: Codable, Equatable, Sendable {
    public let headline: String
    public let points: [String]

    public init(
        headline: String,
        points: [String]
    ) {
        self.headline = headline
        self.points = points
    }
}

public enum CoachError: Error, Equatable, Sendable {
    case notSignedIn
    case unavailable
    case badResponse(Int)
}

public protocol CoachService: Sendable {
    func summarize(match: MatchRecord) async throws -> CoachCard
}

public enum Entitlement: Equatable, Sendable {
    case free
    case trial(expires: Date)
    case pro(expires: Date)
}

public struct SubscriptionProduct: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let displayPrice: String

    public init(
        id: String,
        displayName: String,
        displayPrice: String
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}

public enum SubscriptionError: Error, Equatable, Sendable {
    case productNotFound(String)
    case purchaseUnavailable
}

public protocol SubscriptionService: Sendable {
    func entitlement() async -> Entitlement
    func isTrialAvailable() async -> Bool
    func products() async throws -> [SubscriptionProduct]
    func purchase(_ productID: String) async throws -> Entitlement
    func restore() async throws -> Entitlement
}

public enum HapticEvent: String, Sendable {
    case point
    case game
    case set
    case warning
}

public protocol Haptics: Sendable {
    func play(_ event: HapticEvent)
}

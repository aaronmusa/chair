//
//  AppEnvironment.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

public struct AppEnvironment: Sendable {
    public var auth: any AuthService
    public var speechOutput: any SpeechOutput
    public var speechInput: any SpeechInput
    public var coach: any CoachService
    public var subscription: any SubscriptionService
    public var clock: any ClockProvider
    public var haptics: any Haptics

    public init(
        auth: any AuthService,
        speechOutput: any SpeechOutput,
        speechInput: any SpeechInput,
        coach: any CoachService,
        subscription: any SubscriptionService,
        clock: any ClockProvider,
        haptics: any Haptics
    ) {
        self.auth = auth
        self.speechOutput = speechOutput
        self.speechInput = speechInput
        self.coach = coach
        self.subscription = subscription
        self.clock = clock
        self.haptics = haptics
    }

    public static let unavailable = AppEnvironment(
        auth: UnavailableService(),
        speechOutput: UnavailableService(),
        speechInput: UnavailableService(),
        coach: UnavailableService(),
        subscription: UnavailableService(),
        clock: SystemClock(),
        haptics: UnavailableService()
    )
}

public struct UnavailableService: AuthService, SpeechOutput, SpeechInput, CoachService, SubscriptionService, Haptics {
    public init() {}

    public func currentSession() async -> AuthSession? {
        nil
    }

    public func signInWithApple(
        idToken _: String,
        nonce _: String
    ) async throws -> AuthSession {
        throw AuthError.notSignedIn
    }

    public func signOut() async throws {}
    public func deleteAccount() async throws {
        throw AuthError.accountDeletionUnavailable
    }

    public func speak(_: String) async {}
    public func stop() async {}
    public func route() async -> AudioRoute {
        .speaker
    }

    public func startListening(grammar _: [String]) async throws -> AsyncStream<SpeechEvent> {
        AsyncStream { $0.finish() }
    }

    public func stopListening() async {}

    public func summarize(match _: MatchRecord) async throws -> CoachCard {
        throw CoachError.unavailable
    }

    public func entitlement() async -> Entitlement {
        .free
    }

    public func isTrialAvailable() async -> Bool {
        false
    }

    public func products() async throws -> [SubscriptionProduct] {
        []
    }

    public func purchase(_: String) async throws -> Entitlement {
        throw SubscriptionError.purchaseUnavailable
    }

    public func restore() async throws -> Entitlement {
        .free
    }

    public func play(_: HapticEvent) {}
}

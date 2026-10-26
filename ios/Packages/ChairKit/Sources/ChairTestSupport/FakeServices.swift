//
//  FakeServices.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 10/27/26.
//

#if DEBUG
    import Foundation

    import ChairKit

    public actor FakeAuthService: AuthService {
        public static let sampleSession = AuthSession(
            userID: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
            accessToken: "fake-access-token"
        )

        public private(set) var session: AuthSession?
        public private(set) var calls: [String] = []

        public init(signedIn: Bool = false) {
            session = signedIn ? Self.sampleSession : nil
        }

        public func setSignedIn(_ signedIn: Bool) {
            session = signedIn ? Self.sampleSession : nil
        }

        public func currentSession() async -> AuthSession? {
            calls.append("currentSession")
            return session
        }

        public func signInWithApple(
            idToken _: String,
            nonce _: String
        ) async throws -> AuthSession {
            calls.append("signInWithApple")
            session = Self.sampleSession
            return Self.sampleSession
        }

        public func signOut() async throws {
            calls.append("signOut")
            session = nil
        }

        public func deleteAccount() async throws {
            calls.append("deleteAccount")
            session = nil
        }
    }

    public actor FakeSpeechOutput: SpeechOutput {
        public private(set) var spoken: [String] = []
        public private(set) var stopCount = 0
        public var currentRoute = AudioRoute.speaker

        public init() {}

        public func speak(_ text: String) async {
            spoken.append(text)
        }

        public func stop() async {
            stopCount += 1
        }

        public func route() async -> AudioRoute {
            currentRoute
        }
    }

    public actor FakeSpeechInput: SpeechInput {
        public private(set) var grammars: [[String]] = []
        public private(set) var isListening = false
        private let script: [SpeechEvent]

        public init(script: [SpeechEvent] = []) {
            self.script = script
        }

        public func startListening(grammar: [String]) async throws -> AsyncStream<SpeechEvent> {
            grammars.append(grammar)
            isListening = true
            let events = script
            return AsyncStream { continuation in
                events.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }

        public func stopListening() async {
            isListening = false
        }
    }

    public actor FakeCoachService: CoachService {
        public static let sampleCard = CoachCard(headline: "Serve to the backhand", points: ["Won 7 of 9 points there."])

        public private(set) var summarized: [UUID] = []
        private let result: Result<CoachCard, CoachError>

        public init(result: Result<CoachCard, CoachError> = .success(sampleCard)) {
            self.result = result
        }

        public func summarize(match: MatchRecord) async throws -> CoachCard {
            summarized.append(match.id)
            return try result.get()
        }
    }

    public actor FakeSubscriptionService: SubscriptionService {
        public static let sampleProducts = [
            SubscriptionProduct(id: "chair.pro.monthly", displayName: "Chair Pro Monthly", displayPrice: "$4.99"),
            SubscriptionProduct(id: "chair.pro.yearly", displayName: "Chair Pro Yearly", displayPrice: "$39.99"),
        ]

        public private(set) var current: Entitlement
        public private(set) var purchased: [String] = []
        public private(set) var restoreCount = 0
        public var trialAvailable: Bool

        public init(
            entitlement: Entitlement = .free,
            trialAvailable: Bool = true
        ) {
            current = entitlement
            self.trialAvailable = trialAvailable
        }

        public func setEntitlement(_ entitlement: Entitlement) {
            current = entitlement
        }

        public func entitlement() async -> Entitlement {
            current
        }

        public func isTrialAvailable() async -> Bool {
            trialAvailable
        }

        public func products() async throws -> [SubscriptionProduct] {
            Self.sampleProducts
        }

        public func purchase(_ productID: String) async throws -> Entitlement {
            guard Self.sampleProducts.contains(where: { $0.id == productID }) else {
                throw SubscriptionError.productNotFound(productID)
            }
            purchased.append(productID)
            current = .trial(expires: Fixtures.matchDay.addingTimeInterval(7 * 24 * 60 * 60))
            trialAvailable = false
            return current
        }

        public func restore() async throws -> Entitlement {
            restoreCount += 1
            return current
        }
    }

    public final class FakeHaptics: Haptics, @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [HapticEvent] = []

        public init() {}

        public var played: [HapticEvent] {
            lock.withLock { recorded }
        }

        public func play(_ event: HapticEvent) {
            lock.withLock { recorded.append(event) }
        }
    }

    public extension AppEnvironment {
        static func fakes(clock: FixedClock = FixedClock(Fixtures.matchDay)) -> AppEnvironment {
            AppEnvironment(
                auth: FakeAuthService(),
                speechOutput: FakeSpeechOutput(),
                speechInput: FakeSpeechInput(),
                coach: FakeCoachService(),
                subscription: FakeSubscriptionService(),
                clock: clock,
                haptics: FakeHaptics()
            )
        }
    }
#endif

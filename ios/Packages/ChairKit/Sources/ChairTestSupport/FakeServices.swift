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

        public private(set) var session: AuthSession? {
            didSet { continuations.values.forEach { $0.yield(session) } }
        }

        public private(set) var calls: [String] = []
        private var continuations: [UUID: AsyncStream<AuthSession?>.Continuation] = [:]

        public init(signedIn: Bool = false) {
            session = signedIn ? Self.sampleSession : nil
        }

        public func setSignedIn(_ signedIn: Bool) {
            session = signedIn ? Self.sampleSession : nil
        }

        public var sessionStream: AsyncStream<AuthSession?> {
            let (stream, continuation) = AsyncStream<AuthSession?>.makeStream()
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(session)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
            return stream
        }

        private func removeContinuation(_ id: UUID) {
            continuations[id] = nil
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

        public func signIn(
            email _: String,
            password _: String
        ) async throws -> AuthSession {
            calls.append("signIn")
            session = Self.sampleSession
            return Self.sampleSession
        }
    }

    public actor FakeSpeechOutput: SpeechOutput {
        public private(set) var spoken: [String] = []
        public private(set) var spokenAt: [UInt64] = []
        public private(set) var calls: [UmpireCall] = []
        public private(set) var callsAt: [UInt64] = []
        public private(set) var stopCount = 0
        public var currentRoute = AudioRoute.speaker

        public init() {}

        public func speak(_ calls: [UmpireCall]) async {
            let now = mach_absolute_time()
            self.calls += calls
            callsAt += calls.map { _ in now }
        }

        public func speak(_ text: String) async {
            spoken.append(text)
            spokenAt.append(mach_absolute_time())
        }

        public func stop() async {
            stopCount += 1
        }

        public func route() async -> AudioRoute {
            currentRoute
        }
    }

    public actor FakeCuePlayer: CuePlaying {
        public private(set) var played: [CueKind] = []
        public private(set) var endedAt: [UInt64] = []
        public private(set) var stopCount = 0
        private let duration: Duration

        public init(duration: Duration = .milliseconds(250)) {
            self.duration = duration
        }

        public func play(_ cue: CueKind) async {
            played.append(cue)
            try? await Task.sleep(for: duration)
            endedAt.append(mach_absolute_time())
        }

        public func stop() async {
            stopCount += 1
        }

        public private(set) var volume: Float = 1

        public func setVolume(_ volume: Float) async {
            self.volume = volume
        }
    }

    @MainActor
    public final class FakeSynthesizer: Synthesizing {
        public var voiceID: String?
        public var volume: Float = 1
        public private(set) var said: [String] = []
        public private(set) var saidAt: [UInt64] = []
        public private(set) var voices: [String?] = []
        public private(set) var interrupted: [String] = []
        public private(set) var warmUps = 0
        public var startedAt: UInt64? {
            saidAt.last
        }

        private let duration: Duration
        private var stopping = false

        public init(duration: Duration = .milliseconds(300)) {
            self.duration = duration
        }

        public func say(_ text: String) async {
            said.append(text)
            saidAt.append(mach_absolute_time())
            voices.append(voiceID)
            stopping = false
            let end = ContinuousClock.now + duration
            while ContinuousClock.now < end, !stopping {
                try? await Task.sleep(for: .milliseconds(5))
            }
            if stopping {
                interrupted.append(text)
            }
        }

        public func stopAtWordBoundary() {
            stopping = true
        }

        public func stopNow() {
            stopping = true
        }

        public func warmUp() {
            warmUps += 1
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

    public final class FakeMatchDefaultsStore: MatchDefaultsStore, @unchecked Sendable {
        private let lock = NSLock()
        private var stored: MatchDefaults
        private var saveCount = 0

        public init(_ defaults: MatchDefaults = MatchDefaults()) {
            stored = defaults
        }

        public var saves: Int {
            lock.withLock { saveCount }
        }

        public func load() -> MatchDefaults {
            lock.withLock { stored }
        }

        public func save(_ defaults: MatchDefaults) {
            lock.withLock {
                stored = defaults
                saveCount += 1
            }
        }
    }

    public final class FakeNetworkMonitor: NetworkMonitor, @unchecked Sendable {
        private let lock = NSLock()
        private var continuations: [AsyncStream<Bool>.Continuation] = []
        private var online: Bool

        public init(online: Bool = true) {
            self.online = online
        }

        public func reachability() -> AsyncStream<Bool> {
            let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
            lock.withLock {
                continuations.append(continuation)
                continuation.yield(online)
            }
            return stream
        }

        public func setOnline(_ value: Bool) {
            lock.withLock {
                online = value
                continuations.forEach { $0.yield(value) }
            }
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
                haptics: FakeHaptics(),
                matchDefaults: FakeMatchDefaultsStore(),
                profileRemote: FakeProfileRemote(),
                inviteRemote: FakeInviteRemote()
            )
        }
    }
#endif

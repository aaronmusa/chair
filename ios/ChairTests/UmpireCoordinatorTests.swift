//
//  UmpireCoordinatorTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class UmpireCoordinatorTests: XCTestCase {
    private struct Subject {
        let umpire: UmpireCoordinator
        let speech: FakeSpeechOutput
        let bridge: WatchBridge
        let router: AppRouter
        let repository: LocalMatchRepository
        let match: Match
    }

    private struct Fixture: Decodable {
        let rules: MatchRules
        let format: MatchFormat
        let events: [TimedEvent]
    }

    private var container: ModelContainer?

    func testAPointOnTheLiveScreenSendsItsCueAndScore() async throws {
        let subject = try makeSubject()
        subject.router.presentSession(for: subject.match.remoteID)
        let screen = subject.bridge.session(for: subject.match.remoteID)

        await screen.pointWon(by: .a)

        let calls = try await spokenCalls(subject.speech)
        XCTAssertEqual(calls, [UmpireCall(cue: .point, text: "Forty–fifteen", priority: .score)])
    }

    func testTheSamePointFromTheWatchWithTheScreenClosedSoundsTheSame() async throws {
        let subject = try makeSubject()

        await subject.bridge.receive(WatchInput(.point(.a), matchID: subject.match.remoteID))

        let calls = try await spokenCalls(subject.speech)
        XCTAssertNil(subject.router.presentedMatch)
        XCTAssertEqual(calls, [UmpireCall(cue: .point, text: "Forty–fifteen", priority: .score)])
    }

    func testMutedTheUmpireSaysNothingButTheStripStillUpdates() async throws {
        let subject = try makeSubject()
        let screen = subject.bridge.session(for: subject.match.remoteID)
        subject.umpire.toggleMute()

        await screen.pointWon(by: .a)
        try await Task.sleep(for: .milliseconds(200))

        let calls = await subject.speech.calls
        XCTAssertTrue(subject.umpire.isMuted)
        XCTAssertTrue(calls.isEmpty)
        XCTAssertEqual(screen.announcementText, "Forty–fifteen")
    }

    func testTwoUndosHalfASecondApartSayOneCorrectionWithTheFinalScore() async throws {
        let subject = try makeSubject()
        let screen = subject.bridge.session(for: subject.match.remoteID)

        await screen.apply(.undo)
        try await Task.sleep(for: .milliseconds(500))
        await screen.apply(.undo)
        try await Task.sleep(for: .milliseconds(2300))

        let calls = await subject.speech.calls
        XCTAssertEqual(calls.map(\.text), ["Correction, fifteen–love"])
        XCTAssertEqual(calls.first?.priority, .structural)
    }

    func testAPointAfterAnUndoDropsTheHeldCorrection() async throws {
        let subject = try makeSubject()
        let screen = subject.bridge.session(for: subject.match.remoteID)

        await screen.apply(.undo)
        await screen.pointWon(by: .b)
        try await Task.sleep(for: .milliseconds(2300))

        let calls = await subject.speech.calls
        XCTAssertEqual(calls.map(\.text), ["Fifteen–thirty"])
    }

    func testANewMatchCallsTheServerOnceAndNeverRepeatsIt() async throws {
        let subject = try makeSubject(match: freshMatch())
        let screen = subject.bridge.session(for: subject.match.remoteID)
        let first = try await spokenCalls(subject.speech)

        await screen.apply(.swapEnds)
        try await Task.sleep(for: .milliseconds(200))

        let calls = await subject.speech.calls
        XCTAssertEqual(first.map(\.text), ["Musa to serve, deuce side"])
        XCTAssertEqual(calls.map(\.text), ["Musa to serve, deuce side", "Change of ends"])
    }

    func testTheSinglesFixtureReplaysToTheGoldenCalls() throws {
        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../Packages/ChairKit/Tests/ChairKitTests/Fixtures")
        let data = try Data(contentsOf: fixtures.appending(path: "full_singles_bo3.json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        let golden = try String(contentsOf: fixtures.appending(path: "singles_bo3.calls.txt"), encoding: .utf8)
        let umpire = try UmpireCoordinator(speech: FakeSpeechOutput(), settings: UmpireSettings(userDefaults: makeDefaults()))
        let formatter = AnnouncementFormatter(names: PlayerNames([.a1: "Musa", .b1: "Cruz"], doubles: false))
        var log = try MatchLog(rules: fixture.rules, format: fixture.format)
        var spoken: [String] = []

        for event in fixture.events {
            let announcements = try log.append(event)
            let output = EngineOutput(state: log.state, announcements: announcements)
            if let call = umpire.call(for: output, formatter: formatter) {
                spoken.append(call.text)
            }
        }

        XCTAssertEqual(spoken.joined(separator: "\n") + "\n", golden)
    }

    func testAPhoneCallEndingReannouncesTheScoreOnce() async throws {
        let notifications = NotificationCenter()
        let audio = UmpireAudioSession(routing: AudioRouting(), notifications: notifications)
        addTeardownBlock { @MainActor in audio.end() }
        let subject = try makeSubject(audio: audio)
        let screen = subject.bridge.session(for: subject.match.remoteID)
        await screen.pointWon(by: .a)
        _ = try await spokenCalls(subject.speech)

        notifications.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
        ])
        notifications.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
        ])
        try await Task.sleep(for: .milliseconds(200))

        let calls = await subject.speech.calls
        let stops = await subject.speech.stopCount
        XCTAssertEqual(calls.map(\.text), ["Forty–fifteen", "Forty–fifteen, Musa to serve"])
        XCTAssertEqual(stops, 1)
    }

    func testTheLatencyFromOutputToFirstSoundIsMeasured() async throws {
        let speech = UmpireSpeech(synthesizer: FakeSynthesizer(duration: .zero), cues: FakeCuePlayer(duration: .zero))
        let subject = try makeSubject(speech: speech)
        let screen = subject.bridge.session(for: subject.match.remoteID)

        await screen.pointWon(by: .a)
        for _ in 0 ..< 100 where subject.umpire.lastLatency == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        let latency = try XCTUnwrap(subject.umpire.lastLatency)
        XCTAssertLessThan(latency, 300)
        XCTAssertEqual(subject.umpire.stripNote, "\(latency) ms")
    }

    func testASpeakerDisconnectNoteStaysForTheNextCallOnly() async throws {
        let subject = try makeSubject()
        let screen = subject.bridge.session(for: subject.match.remoteID)
        subject.umpire.routing.routeChanged(reason: .oldDeviceUnavailable)

        await screen.pointWon(by: .a)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(subject.umpire.stripNote?.hasPrefix("Speaker disconnected"), true)
        await screen.pointWon(by: .b)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertNil(subject.umpire.routing.note)
    }

    private func spokenCalls(_ speech: FakeSpeechOutput) async throws -> [UmpireCall] {
        for _ in 0 ..< 100 {
            let calls = await speech.calls
            if !calls.isEmpty {
                return calls
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        return []
    }

    private func freshMatch() -> Match {
        let match = Match(playedAt: Fixtures.matchDay, format: .singles, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
        match.players = [MatchPlayer.sample(.a1, name: "Musa"), MatchPlayer.sample(.b1, name: "Reyes")]
        return match
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "UmpireCoordinatorTests.\(UUID())"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    private func sessionFactory(_ repository: LocalMatchRepository) -> WatchBridge.SessionFactory {
        { matchID in
            MatchSessionViewModel(
                matchID: matchID,
                repository: repository,
                clock: FixedClock(Fixtures.matchDay),
                asksHowPointEnded: false
            )
        }
    }

    private func makeSubject(
        match: Match = .sample(),
        speech: any SpeechOutput = FakeSpeechOutput(),
        audio: UmpireAudioSession? = nil
    ) throws -> Subject {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext)
        try repository.save(match)
        let router = AppRouter()
        let bridge = WatchBridge(
            link: WatchLink(transport: FakeWCSession()),
            router: router,
            repository: repository,
            makeSession: sessionFactory(repository)
        )
        let umpire = try UmpireCoordinator(speech: speech, settings: UmpireSettings(userDefaults: makeDefaults()), audio: audio)
        bridge.onNewSession = umpire.handleNewSession()
        return Subject(
            umpire: umpire,
            speech: speech as? FakeSpeechOutput ?? FakeSpeechOutput(),
            bridge: bridge,
            router: router,
            repository: repository,
            match: match
        )
    }
}

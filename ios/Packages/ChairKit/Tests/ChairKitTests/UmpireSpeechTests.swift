//
//  UmpireSpeechTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class UmpireSpeechTests: XCTestCase {
    private struct Subject {
        let speech: UmpireSpeech
        let synthesizer: FakeSynthesizer
        let cues: FakeCuePlayer
    }

    func testWithCuesOnFastScoresReplaceEachOtherDuringTheCue() async throws {
        let subject = makeSubject(cuesOn: true)

        try await scoreThreeTimes(subject.speech)
        await subject.speech.drained()

        XCTAssertEqual(subject.synthesizer.said, ["Forty–love"])
    }

    func testWithCuesOffTheFirstScoreFinishesAndOnlyTheLatestWaitingOneFollows() async throws {
        let subject = makeSubject(cuesOn: false)

        try await scoreThreeTimes(subject.speech)
        await subject.speech.drained()

        XCTAssertEqual(subject.synthesizer.said, ["Fifteen–love", "Forty–love"])
        XCTAssertTrue(subject.synthesizer.interrupted.isEmpty)
    }

    func testAGameCallCutsTheScoreAtAWordBoundary() async throws {
        let subject = makeSubject(cuesOn: false)

        await subject.speech.speak([call("Thirty–fifteen", .score)])
        try await Task.sleep(for: .milliseconds(100))
        await subject.speech.speak([call("Game, Musa", .structural)])
        await subject.speech.drained()

        XCTAssertEqual(subject.synthesizer.said, ["Thirty–fifteen", "Game, Musa"])
        XCTAssertEqual(subject.synthesizer.interrupted, ["Thirty–fifteen"])
    }

    func testAStructuralCallDropsWhatIsWaitingAndInterruptsWhatIsSpoken() async throws {
        let subject = makeSubject(cuesOn: false)

        await subject.speech.speak([call("Fifteen–love", .score)])
        try await Task.sleep(for: .milliseconds(50))
        await subject.speech.speak([call("Thirty–love", .score)])
        await subject.speech.speak([call("Out", .call)])
        await subject.speech.speak([call("Game, Musa", .structural), call("Change of ends", .structural)])
        await subject.speech.drained()

        XCTAssertEqual(subject.synthesizer.said, ["Fifteen–love", "Game, Musa", "Change of ends"])
        XCTAssertEqual(subject.synthesizer.interrupted, ["Fifteen–love"])
    }

    func testANewerCallDropsAWaitingScore() async throws {
        let subject = makeSubject(cuesOn: false)

        await subject.speech.speak([call("Fifteen–love", .score)])
        try await Task.sleep(for: .milliseconds(50))
        await subject.speech.speak([call("Thirty–love", .score)])
        await subject.speech.speak([call("Out. Forty–love", .call)])
        await subject.speech.drained()

        XCTAssertEqual(subject.synthesizer.said, ["Fifteen–love", "Out. Forty–love"])
    }

    func testCallsNeverOverlap() async {
        let subject = makeSubject(cuesOn: true)

        for text in ["Out", "Ace!", "Net"] {
            await subject.speech.speak([call(text, .call)])
        }
        await subject.speech.drained()

        let starts = subject.synthesizer.saidAt.map { AVAudioTime.seconds(forHostTime: $0) }
        XCTAssertEqual(subject.synthesizer.said, ["Out", "Ace!", "Net"])
        for (earlier, later) in zip(starts, starts.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later - earlier, 0.3)
        }
    }

    func testStopClearsTheQueueAndCutsTheCurrentCall() async throws {
        let subject = makeSubject(cuesOn: false)

        await subject.speech.speak([call("Out", .call), call("Fifteen–love", .call)])
        try await Task.sleep(for: .milliseconds(50))
        await subject.speech.stop()
        await subject.speech.drained()

        XCTAssertEqual(subject.synthesizer.said, ["Out"])
        XCTAssertEqual(subject.synthesizer.interrupted, ["Out"])
        XCTAssertFalse(subject.speech.isSpeaking)
    }

    func testThePriorityComesFromTheHighestCall() {
        XCTAssertEqual(CallPriority([.score(a: .fifteen, b: .love, serverSide: .a)]), .score)
        XCTAssertEqual(CallPriority([.out, .score(a: .fifteen, b: .love, serverSide: .a)]), .call)
        XCTAssertEqual(CallPriority([.net, .game(.a), .changeEnds]), .structural)
    }

    func testTheBestEnglishVoiceIsChosenAndARemovedVoiceFallsBack() {
        let voices = [
            VoiceOption(id: "gb.enhanced", name: "Daniel", language: "en-GB", quality: .enhanced),
            VoiceOption(id: "us.standard", name: "Samantha", language: "en-US", quality: .standard),
            VoiceOption(id: "us.enhanced", name: "Ava", language: "en-US", quality: .enhanced),
        ]

        XCTAssertEqual(VoiceCatalog.pick(nil, from: voices)?.id, "us.enhanced")
        XCTAssertEqual(VoiceCatalog.pick("gb.enhanced", from: voices)?.id, "gb.enhanced")
        XCTAssertEqual(VoiceCatalog.pick("removed.premium", from: voices)?.id, "us.enhanced")
        XCTAssertNil(VoiceCatalog.pick("removed.premium", from: []))
    }

    func testTheRealSynthesizerAcceptsARemovedVoiceWithoutThrowing() {
        let synthesizer = SystemSynthesizer()

        synthesizer.voiceID = "com.apple.voice.premium.en-US.Removed"

        XCTAssertNil(synthesizer.voiceID.flatMap { id in VoiceCatalog.englishVoices().first { $0.id == id } })
    }

    func testWarmUpPrimesTheSynthesizer() {
        let subject = makeSubject(cuesOn: true)

        subject.speech.warmUp()

        XCTAssertEqual(subject.synthesizer.warmUps, 1)
    }

    private func scoreThreeTimes(_ speech: UmpireSpeech) async throws {
        for text in ["Fifteen–love", "Thirty–love", "Forty–love"] {
            await speech.speak([UmpireCall(cue: .point, text: text, priority: .score)])
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func call(
        _ text: String,
        _ priority: CallPriority
    ) -> UmpireCall {
        UmpireCall(cue: nil, text: text, priority: priority)
    }

    private func makeSubject(cuesOn: Bool) -> Subject {
        let synthesizer = FakeSynthesizer()
        let cues = FakeCuePlayer(duration: .milliseconds(400))
        let speech = UmpireSpeech(synthesizer: synthesizer, cues: cues)
        speech.cuesEnabled = cuesOn
        return Subject(speech: speech, synthesizer: synthesizer, cues: cues)
    }
}

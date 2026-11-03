//
//  CueTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class CueTests: XCTestCase {
    func testAPointPlaysThePointCueAndSpeechFollowsWithin50ms() async throws {
        let cues = FakeCuePlayer()
        let synthesizer = FakeSynthesizer(duration: .zero)
        let calls: [Announcement] = [.out, .score(a: .fifteen, b: .love, serverSide: .a)]
        let speech = UmpireSpeech(synthesizer: synthesizer, cues: cues)

        await speech.speak([UmpireCall(cue: CueKind(calls), text: "Out. Fifteen–love", priority: .call)])
        await speech.drained()

        let played = await cues.played
        let cueEnds = await cues.endedAt
        let cueEnd = try XCTUnwrap(cueEnds.first)
        let speechStart = try XCTUnwrap(synthesizer.saidAt.first)
        XCTAssertEqual(played, [.point])
        XCTAssertLessThan(AVAudioTime.seconds(forHostTime: speechStart - cueEnd), 0.05)
    }

    func testASetWonPlaysTheSetCueOnce() async {
        let cues = FakeCuePlayer(duration: .zero)
        let calls: [Announcement] = [.net, .game(.b), .changeEnds, .gameAndSet(.b, SetScore(a: 3, b: 6))]
        let speech = UmpireSpeech(synthesizer: FakeSynthesizer(duration: .zero), cues: cues)

        await speech.speak([UmpireCall(cue: CueKind(calls), text: "Game and set", priority: .structural)])
        await speech.drained()

        let played = await cues.played
        XCTAssertEqual(played, [.set])
    }

    func testTheHighestRankingCallPicksTheCue() {
        XCTAssertEqual(CueKind([.out, .game(.b)]), .game)
        XCTAssertEqual(CueKind([.ace, .score(a: .fifteen, b: .love, serverSide: .a)]), .point)
        XCTAssertEqual(CueKind([.fault]), .point)
        XCTAssertEqual(CueKind([.game(.a), .gameSetMatch(.a, [])]), .set)
    }

    func testCorrectionsAndPreRallyOnlyHaveNoCue() {
        let snapshot = ScoreSnapshot(sets: [], currentSet: SetScore(a: 0, b: 0), currentGame: .loveAll, server: .a1)

        XCTAssertNil(CueKind([.correction(snapshot)]))
        XCTAssertNil(CueKind([.changeEnds]))
        XCTAssertNil(CueKind([]))
    }

    func testWithCuesOffSpeechStartsWithNoCue() async {
        let cues = FakeCuePlayer()
        let synthesizer = FakeSynthesizer(duration: .zero)
        let speech = UmpireSpeech(synthesizer: synthesizer, cues: cues)
        speech.cuesEnabled = false

        await speech.speak([UmpireCall(cue: .point, text: "Fifteen–love", priority: .score)])
        await speech.drained()

        let played = await cues.played
        XCTAssertTrue(played.isEmpty)
        XCTAssertEqual(synthesizer.said, ["Fifteen–love"])
    }

    func testTheRealPlayerHandsOverWithin50msOfTheCueEnding() async throws {
        let player = CuePlayer()
        let length = try AVAudioFile(forReading: XCTUnwrap(CueKind.point.url)).duration
        let start = mach_absolute_time()

        await player.play(.point)

        let elapsed = AVAudioTime.seconds(forHostTime: mach_absolute_time() - start)
        XCTAssertGreaterThanOrEqual(elapsed, length)
        XCTAssertLessThan(elapsed, length + 0.08)
    }

    func testEveryCueDecodesAndIsUnder400ms() throws {
        for cue in CueKind.allCases {
            let seconds = try AVAudioFile(forReading: XCTUnwrap(cue.url, "\(cue) is missing")).duration

            XCTAssertGreaterThan(seconds, 0, "\(cue)")
            XCTAssertLessThan(seconds, 0.4, "\(cue)")
        }
    }
}

private extension AVAudioFile {
    var duration: Double {
        Double(length) / processingFormat.sampleRate
    }
}

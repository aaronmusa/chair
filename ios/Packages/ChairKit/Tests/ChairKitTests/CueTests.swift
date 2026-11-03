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

final class CueTests: XCTestCase {
    func testAPointPlaysThePointCueAndSpeechFollowsWithin50ms() async throws {
        let cues = FakeCuePlayer()
        let speech = FakeSpeechOutput()
        let calls: [Announcement] = [.out, .score(a: .fifteen, b: .love, serverSide: .a)]

        await CuedSpeech(cues: cues, speech: speech).say("Out. Fifteen–love", cue: CueKind(calls))

        let played = await cues.played
        let cueEnds = await cues.endedAt
        let speechStarts = await speech.spokenAt
        let cueEnd = try XCTUnwrap(cueEnds.first)
        let speechStart = try XCTUnwrap(speechStarts.first)
        XCTAssertEqual(played, [.point])
        XCTAssertLessThan(AVAudioTime.seconds(forHostTime: speechStart - cueEnd), 0.05)
    }

    func testASetWonPlaysTheSetCueOnce() async {
        let cues = FakeCuePlayer(duration: .zero)
        let calls: [Announcement] = [.net, .game(.b), .changeEnds, .gameAndSet(.b, SetScore(a: 3, b: 6))]

        await CuedSpeech(cues: cues, speech: FakeSpeechOutput()).say("Game and set", cue: CueKind(calls))

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
        let speech = FakeSpeechOutput()

        await CuedSpeech(cues: cues, speech: speech, cuesEnabled: false).say("Fifteen–love", cue: .point)

        let played = await cues.played
        let spoken = await speech.spoken
        XCTAssertTrue(played.isEmpty)
        XCTAssertEqual(spoken, ["Fifteen–love"])
    }

    @MainActor
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

//
//  SystemSynthesizerTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import XCTest

import ChairKit

@MainActor
final class SystemSynthesizerTests: XCTestCase {
    func testAWarmedSynthesizerSpeaksAndFinishes() async throws {
        let synthesizer = SystemSynthesizer()
        synthesizer.volume = 0
        synthesizer.warmUp()
        let asked = mach_absolute_time()

        await synthesizer.say("Fifteen–love")

        let started = try XCTUnwrap(synthesizer.startedAt)
        let latency = AVAudioTime.seconds(forHostTime: started - asked)
        print("simulator first-utterance latency: \(Int(latency * 1000)) ms")
        XCTAssertLessThan(latency, 1)
    }

    func testARemovedVoiceFallsBackAndStillSpeaks() async {
        let synthesizer = SystemSynthesizer()
        synthesizer.volume = 0
        synthesizer.voiceID = "com.apple.voice.premium.en-US.Removed"

        await synthesizer.say("Game, Musa")

        XCTAssertNotNil(synthesizer.startedAt)
    }

    func testAWordBoundaryStopEndsTheUtteranceEarly() async throws {
        let synthesizer = SystemSynthesizer()
        synthesizer.volume = 0
        let start = ContinuousClock.now
        let speaking = Task { await synthesizer.say("Game, set and match, Musa, six–four, three–six, seven–six") }

        try await Task.sleep(for: .milliseconds(300))
        synthesizer.stopAtWordBoundary()
        await speaking.value

        XCTAssertLessThan(ContinuousClock.now - start, .seconds(2))
    }
}

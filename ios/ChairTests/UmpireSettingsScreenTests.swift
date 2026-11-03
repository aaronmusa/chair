//
//  UmpireSettingsScreenTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class UmpireSettingsScreenTests: XCTestCase {
    private struct Fixture: Decodable {
        let rules: MatchRules
        let format: MatchFormat
        let events: [TimedEvent]
    }

    func testPreviewSpeaksFifteenLoveInTheChosenVoice() async {
        let synthesizer = FakeSynthesizer(duration: .zero)
        let speech = UmpireSpeech(synthesizer: synthesizer, cues: FakeCuePlayer(duration: .zero))
        let umpire = UmpireCoordinator(speech: speech, settings: .fake(UmpirePreferences(voiceID: "com.apple.voice.enhanced.en-GB.Daniel")))

        await umpire.preview()
        await speech.drained()

        XCTAssertEqual(synthesizer.said, ["Fifteen–love"])
        XCTAssertEqual(synthesizer.voices, ["com.apple.voice.enhanced.en-GB.Daniel"])
    }

    func testTheTestCallPlaysTheSetCueThenGameSetAndMatch() async {
        let synthesizer = FakeSynthesizer(duration: .zero)
        let cues = FakeCuePlayer(duration: .zero)
        let speech = UmpireSpeech(synthesizer: synthesizer, cues: cues)
        let umpire = UmpireCoordinator(speech: speech, settings: .fake())

        await umpire.testCall()
        await speech.drained()

        let played = await cues.played
        XCTAssertEqual(played, [.set])
        XCTAssertEqual(synthesizer.said, ["Game, set and match"])
    }

    func testMinimalVerbosityCallsOnlyScoresAndResultsThroughTheFixture() throws {
        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../Packages/ChairKit/Tests/ChairKitTests/Fixtures")
        let data = try Data(contentsOf: fixtures.appending(path: "full_singles_bo3.json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        let umpire = UmpireCoordinator(speech: FakeSpeechOutput(), settings: .fake(UmpirePreferences(verbosity: .minimal)))
        let formatter = umpire.formatter(for: PlayerNames([.a1: "Musa", .b1: "Cruz"], doubles: false))
        var log = try MatchLog(rules: fixture.rules, format: fixture.format)
        var spoken: [String] = []
        var pointsWon = 0

        for event in fixture.events {
            let announcements = try log.append(event)
            if case .pointWon = event.event {
                pointsWon += 1
            } else if announcements.contains(.doubleFault) {
                pointsWon += 1
            }
            if let call = umpire.call(for: EngineOutput(state: log.state, announcements: announcements), formatter: formatter) {
                spoken.append(call.text)
            }
        }

        let banned = ["Ace", "Out", "Net", "Fault", "Let", "Change of ends", "to serve", "Second serve"]
        XCTAssertEqual(spoken.count, pointsWon)
        XCTAssertEqual(spoken.filter { line in banned.contains { line.contains($0) } }, [])
        XCTAssertEqual(spoken.last, "Game, set and match, Musa, six–four, three–six, seven–six")
    }

    func testTheSpeakerTipShowsOnceOnThePhoneSpeaker() {
        let settings = UmpireSettings.fake()
        let umpire = UmpireCoordinator(speech: FakeSpeechOutput(), settings: settings)

        XCTAssertTrue(umpire.showsSpeakerTip)
        umpire.dismissSpeakerTip()

        XCTAssertFalse(umpire.showsSpeakerTip)
        XCTAssertTrue(settings.preferences.speakerTipShown)
    }
}

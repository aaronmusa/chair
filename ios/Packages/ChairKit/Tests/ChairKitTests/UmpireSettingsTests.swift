//
//  UmpireSettingsTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class UmpireSettingsTests: XCTestCase {
    func testTheDefaultsAreOnNormalWithCuesAndTheSilentSwitchIgnored() throws {
        let settings = try UmpireSettings(userDefaults: makeDefaults())

        XCTAssertEqual(settings.preferences, UmpirePreferences())
        XCTAssertTrue(settings.preferences.isEnabled)
        XCTAssertTrue(settings.preferences.cuesEnabled)
        XCTAssertFalse(settings.preferences.respectsSilentMode)
        XCTAssertFalse(settings.preferences.keepsAudioAlive)
        XCTAssertEqual(settings.preferences.verbosity, .normal)
    }

    func testChangesSurviveARelaunch() throws {
        let defaults = try makeDefaults()
        let settings = UmpireSettings(userDefaults: defaults)

        settings.preferences.respectsSilentMode = true
        settings.preferences.volume = 0.7

        XCTAssertEqual(UmpireSettings(userDefaults: defaults).preferences, settings.preferences)
    }

    func testTheVolumeStaysBetweenHalfAndFull() {
        XCTAssertEqual(UmpirePreferences(volume: 0.1).clampedVolume, 0.5)
        XCTAssertEqual(UmpirePreferences(volume: 0.8).clampedVolume, 0.8)
        XCTAssertEqual(UmpirePreferences(volume: 3).clampedVolume, 1)
    }

    func testApplyingPreferencesSetsTheVoiceVolumeAndCues() async {
        let synthesizer = FakeSynthesizer()
        let cues = FakeCuePlayer()
        let speech = UmpireSpeech(synthesizer: synthesizer, cues: cues)

        await speech.apply(UmpirePreferences(voiceID: "en-GB.Daniel", cuesEnabled: false, volume: 0.6))

        let cueVolume = await cues.volume
        XCTAssertEqual(synthesizer.voiceID, "en-GB.Daniel")
        XCTAssertEqual(synthesizer.volume, 0.6)
        XCTAssertEqual(cueVolume, 0.6)
        XCTAssertFalse(speech.cuesEnabled)
    }

    func testTheKeepAliveLoopsSilenceAtVolumeZero() {
        let player = KeepAlivePlayer()
        XCTAssertNotNil(KeepAlivePlayer.silence)

        player.start()
        XCTAssertTrue(player.isRunning)
        XCTAssertEqual(player.playerVolume, 0)
        player.stop()

        XCTAssertFalse(player.isRunning)
    }

    func testTheResumptionReadsTheScoreAndTheServer() throws {
        var log = try MatchLog(rules: MatchRules())
        let formatter = AnnouncementFormatter(names: PlayerNames([.a1: "Musa", .b1: "Cruz"], doubles: false))
        for winner in [Side.a, .a, .b] {
            try log.append(TimedEvent(.pointWon(by: winner, outcome: nil, ending: nil), at: Date()))
        }

        XCTAssertEqual(formatter.resumption(log.state), "Thirty–fifteen, Musa to serve")
        try log.append(TimedEvent(.fault, at: Date()))
        XCTAssertEqual(formatter.resumption(log.state), "Thirty–fifteen, Musa to serve, second serve")
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "UmpireSettingsTests.\(UUID())"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }
}

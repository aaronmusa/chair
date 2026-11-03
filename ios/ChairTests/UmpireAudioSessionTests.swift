//
//  UmpireAudioSessionTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import XCTest

import ChairKit

@testable import Chair

@MainActor
final class UmpireAudioSessionTests: XCTestCase {
    func testByDefaultTheUmpirePlaysThroughSilentModeAndDucksOtherAudio() {
        let session = makeSubject()

        session.begin(UmpirePreferences())

        let audio = AVAudioSession.sharedInstance()
        XCTAssertEqual(audio.category, .playback)
        XCTAssertEqual(audio.mode, .spokenAudio)
        XCTAssertTrue(audio.categoryOptions.contains(.duckOthers))
        XCTAssertTrue(audio.categoryOptions.contains(.interruptSpokenAudioAndMixWithOthers))
        XCTAssertTrue(session.isActive)
    }

    func testRespectingSilentModeSwitchesToAmbient() {
        let session = makeSubject()

        session.begin(UmpirePreferences(respectsSilentMode: true))

        XCTAssertEqual(AVAudioSession.sharedInstance().category, .ambient)
        XCTAssertEqual(UmpireAudioSession.configuration(respectsSilentMode: true).options, [])
    }

    func testTheKeepAliveRunsOnlyWhenItsFlagIsOn() {
        let session = makeSubject()

        session.begin(UmpirePreferences())
        XCTAssertFalse(session.isKeepingAlive)
        session.end()
        session.begin(UmpirePreferences(keepsAudioAlive: true))
        XCTAssertTrue(session.isKeepingAlive)
        session.end()

        XCTAssertFalse(session.isKeepingAlive)
        XCTAssertFalse(session.isActive)
    }

    func testAPhoneCallPausesAndTheEndResumesOnce() {
        let notifications = NotificationCenter()
        let session = makeSubject(notifications: notifications)
        var events: [UmpireAudioSession.Event] = []
        session.onEvent = { events.append($0) }
        session.begin(UmpirePreferences())

        post(notifications, AVAudioSession.interruptionNotification, [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
        ])
        post(notifications, AVAudioSession.interruptionNotification, [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue,
        ])

        XCTAssertEqual(events, [.interrupted, .resumed])
    }

    func testAnInterruptionThatShouldNotResumeStaysQuiet() {
        let session = makeSubject()
        var events: [UmpireAudioSession.Event] = []
        session.onEvent = { events.append($0) }

        session.handleInterruption([AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])

        XCTAssertTrue(events.isEmpty)
    }

    func testASpeakerDisconnectingLeavesANoteAndFallsBackToTheSpeaker() {
        let notifications = NotificationCenter()
        let session = makeSubject(notifications: notifications)
        session.begin(UmpirePreferences())

        post(notifications, AVAudioSession.routeChangeNotification, [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
        ])

        XCTAssertEqual(session.routing.note, "Speaker disconnected")
        XCTAssertFalse(session.routing.currentRouteName.isEmpty)
    }

    func testAnEndedSessionStopsListening() {
        let notifications = NotificationCenter()
        let session = makeSubject(notifications: notifications)
        session.begin(UmpirePreferences())
        session.end()

        post(notifications, AVAudioSession.routeChangeNotification, [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
        ])

        XCTAssertNil(session.routing.note)
    }

    func testRouteNamesReadLikeThePill() {
        XCTAssertEqual(AudioRouting.name(of: [(.builtInSpeaker, "Speaker")]), "Speaker")
        XCTAssertEqual(AudioRouting.name(of: [(.builtInReceiver, "Receiver")]), "Speaker")
        XCTAssertEqual(AudioRouting.name(of: [(.bluetoothA2DP, "JBL Flip")]), "JBL Flip")
        XCTAssertEqual(AudioRouting.name(of: [(.bluetoothA2DP, "AirPods")]), "AirPods")
        XCTAssertEqual(AudioRouting.name(of: []), "Speaker")
        XCTAssertNil(AudioRouting.note(for: .newDeviceAvailable))
    }

    private func post(
        _ notifications: NotificationCenter,
        _ name: Notification.Name,
        _ userInfo: [AnyHashable: Any]
    ) {
        notifications.post(name: name, object: nil, userInfo: userInfo)
    }

    private func makeSubject(notifications: NotificationCenter = NotificationCenter()) -> UmpireAudioSession {
        let session = UmpireAudioSession(routing: AudioRouting(), notifications: notifications)
        addTeardownBlock { @MainActor in session.end() }
        return session
    }
}

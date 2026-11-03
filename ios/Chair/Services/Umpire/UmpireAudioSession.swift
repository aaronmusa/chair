//
//  UmpireAudioSession.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import Foundation
import os

import ChairKit

@MainActor
final class UmpireAudioSession {
    struct Configuration: Equatable {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    enum Event: Equatable {
        case interrupted
        case resumed
    }

    private static let log = Logger(subsystem: "com.aaronmusa.chair", category: "audio")

    let routing: AudioRouting
    var onEvent: (Event) -> Void = { _ in }

    private let session: AVAudioSession
    private let notifications: NotificationCenter
    private let keepAlive = KeepAlivePlayer()
    private var observers: [NSObjectProtocol] = []
    private(set) var isActive = false

    init(
        routing: AudioRouting,
        session: AVAudioSession = .sharedInstance(),
        notifications: NotificationCenter = .default
    ) {
        self.routing = routing
        self.session = session
        self.notifications = notifications
    }

    static func configuration(respectsSilentMode: Bool) -> Configuration {
        guard respectsSilentMode else {
            return Configuration(category: .playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        }
        return Configuration(category: .ambient, mode: .spokenAudio, options: [])
    }

    var isKeepingAlive: Bool {
        keepAlive.isRunning
    }

    func begin(_ preferences: UmpirePreferences) {
        let configuration = Self.configuration(respectsSilentMode: preferences.respectsSilentMode)
        do {
            try session.setCategory(configuration.category, mode: configuration.mode, options: configuration.options)
            try session.setActive(true)
        } catch {
            Self.log.error("Umpire audio session failed: \(error)")
        }
        isActive = true
        observe()
        routing.refresh(session.currentRoute)
        if preferences.keepsAudioAlive {
            keepAlive.start()
        }
    }

    func end() {
        keepAlive.stop()
        observers.forEach(notifications.removeObserver)
        observers = []
        isActive = false
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func handleInterruption(_ userInfo: [AnyHashable: Any]) {
        interruption(
            type: userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            options: userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
        )
    }

    func handleRouteChange(_ userInfo: [AnyHashable: Any]) {
        routeChange(reason: userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt)
    }

    private func interruption(
        type rawType: UInt?,
        options rawOptions: UInt?
    ) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            onEvent(.interrupted)
        case .ended:
            let options = rawOptions.map(AVAudioSession.InterruptionOptions.init)
            guard options?.contains(.shouldResume) == true else { return }
            try? session.setActive(true)
            onEvent(.resumed)
        @unknown default:
            break
        }
    }

    private func routeChange(reason rawReason: UInt?) {
        guard let rawReason, let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        routing.routeChanged(reason: reason, route: session.currentRoute)
    }

    private func observe() {
        guard observers.isEmpty else { return }
        observers = [
            notifications.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main,
                using: handleInterruptionNotification()
            ),
            notifications.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main,
                using: handleRouteChangeNotification()
            ),
        ]
    }

    private func handleInterruptionNotification() -> @Sendable (Notification) -> Void {
        { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated { self?.interruption(type: type, options: options) }
        }
    }

    private func handleRouteChangeNotification() -> @Sendable (Notification) -> Void {
        { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.routeChange(reason: reason) }
        }
    }
}

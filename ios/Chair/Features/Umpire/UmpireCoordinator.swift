//
//  UmpireCoordinator.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import Foundation
import Observation
import SwiftUI

import ChairKit

@MainActor
@Observable
final class UmpireCoordinator {
    private(set) var isMuted = false
    private(set) var lastLatency: Int?

    let routing: AudioRouting

    let settings: UmpireSettings

    @ObservationIgnored private let speech: any SpeechOutput
    @ObservationIgnored private let audio: UmpireAudioSession?
    @ObservationIgnored private let correctionWindow: Duration
    @ObservationIgnored private let audioEndDelay: Duration
    @ObservationIgnored private weak var session: MatchSessionViewModel?
    @ObservationIgnored private var following: Task<Void, Never>?
    @ObservationIgnored private var pendingCorrection: Task<Void, Never>?
    @ObservationIgnored private var latencyTask: Task<Void, Never>?
    @ObservationIgnored private var endTask: Task<Void, Never>?
    @ObservationIgnored private var spokenPreRally: PreRallyKey?
    @ObservationIgnored private var noteWasShown = false

    init(
        speech: any SpeechOutput,
        settings: UmpireSettings,
        audio: UmpireAudioSession? = nil,
        correctionWindow: Duration = .seconds(2),
        audioEndDelay: Duration = .seconds(6)
    ) {
        self.speech = speech
        self.settings = settings
        self.audio = audio
        self.correctionWindow = correctionWindow
        self.audioEndDelay = audioEndDelay
        routing = audio?.routing ?? AudioRouting()
        audio?.onEvent = handleAudioEvent()
    }

    var routeName: String {
        routing.currentRouteName
    }

    var stripNote: String? {
        var notes = [routing.note]
        #if DEBUG
            notes.append(lastLatency.map { "\($0) ms" })
        #endif
        let note = notes.compactMap(\.self).joined(separator: " · ")
        return note.isEmpty ? nil : note
    }

    func handleNewSession() -> (MatchSessionViewModel) -> Void {
        { [weak self] session in self?.follow(session) }
    }

    func follow(_ session: MatchSessionViewModel) {
        guard session !== self.session else { return }
        following?.cancel()
        pendingCorrection?.cancel()
        self.session = session
        spokenPreRally = nil
        isMuted = !settings.preferences.isEnabled
        session.verbosity = settings.preferences.verbosity
        let outputs = session.outputs()
        following = Task { [weak self] in
            for await output in outputs {
                self?.handle(output)
            }
        }
    }

    func toggleMute() {
        isMuted.toggle()
        guard isMuted else { return }
        pendingCorrection?.cancel()
        Task { [speech] in await speech.stop() }
    }

    var showsSpeakerTip: Bool {
        !settings.preferences.speakerTipShown && routing.currentRouteName == AudioRouting.speakerName
    }

    func dismissSpeakerTip() {
        settings.preferences.speakerTipShown = true
    }

    func formatter(for names: PlayerNames) -> AnnouncementFormatter {
        AnnouncementFormatter(names: names, verbosity: settings.preferences.verbosity)
    }

    func preview() async {
        await applySettings()
        await speech.speak([UmpireCall(cue: nil, text: "Fifteen–love", priority: .structural)])
    }

    func testCall() async {
        await applySettings()
        await speech.speak([UmpireCall(cue: .set, text: "Game, set and match", priority: .structural)])
    }

    func applySettings() async {
        session?.verbosity = settings.preferences.verbosity
        await (speech as? UmpireSpeech)?.apply(settings.preferences)
    }

    func handle(_ output: EngineOutput) {
        guard let session, !session.isReadOnly else { return }
        session.verbosity = settings.preferences.verbosity
        if Self.isOver(output.state) {
            scheduleAudioEnd()
        } else {
            beginAudio()
        }
        let formatter = formatter(for: session.playerNames)
        let isCorrection = output.announcements.contains(where: Self.isCorrection)
        pendingCorrection?.cancel()
        guard let call = call(for: output, formatter: formatter) else { return }
        updateNote()
        if isCorrection {
            holdCorrection(call)
        } else {
            say(call)
        }
    }

    func call(
        for output: EngineOutput,
        formatter: AnnouncementFormatter
    ) -> UmpireCall? {
        guard !output.announcements.isEmpty || output.state.phase == .notStarted else { return nil }
        let key = PreRallyKey(output)
        let isRepeat = key == spokenPreRally
        if formatter.preRally(output) != nil, !isRepeat {
            spokenPreRally = key
        }
        let text = formatter.spoken(output, includesPreRally: !isRepeat)
        guard !text.isEmpty else { return nil }
        return UmpireCall(cue: CueKind(output.announcements), text: text, priority: CallPriority(output.announcements))
    }

    private func say(_ call: UmpireCall) {
        guard !isMuted else { return }
        let askedAt = mach_absolute_time()
        Task { [speech] in await speech.speak([call]) }
        measureLatency(from: askedAt)
    }

    private func holdCorrection(_ call: UmpireCall) {
        pendingCorrection = Task { [weak self, correctionWindow] in
            try? await Task.sleep(for: correctionWindow)
            guard let self, !Task.isCancelled else { return }
            say(call)
        }
    }

    private func measureLatency(from askedAt: UInt64) {
        guard let umpire = speech as? UmpireSpeech else { return }
        latencyTask?.cancel()
        latencyTask = Task { [weak self] in
            for _ in 0 ..< 300 {
                if let heard = umpire.firstSound(after: askedAt) {
                    self?.lastLatency = Int(AVAudioTime.seconds(forHostTime: heard - askedAt) * 1000)
                    return
                }
                try? await Task.sleep(for: .milliseconds(10))
                guard !Task.isCancelled else { return }
            }
        }
    }

    private func updateNote() {
        guard routing.note != nil else { return }
        if noteWasShown {
            routing.clearNote()
        }
        noteWasShown.toggle()
    }

    private func beginAudio() {
        endTask?.cancel()
        guard let audio, !audio.isActive else { return }
        audio.begin(settings.preferences)
        let preferences = settings.preferences
        guard let umpire = speech as? UmpireSpeech else { return }
        Task {
            await umpire.apply(preferences)
            umpire.warmUp()
        }
    }

    private func scheduleAudioEnd() {
        endTask?.cancel()
        endTask = Task { [weak self, audioEndDelay] in
            try? await Task.sleep(for: audioEndDelay)
            guard let self, !Task.isCancelled else { return }
            audio?.end()
        }
    }

    private func handleAudioEvent() -> (UmpireAudioSession.Event) -> Void {
        { [weak self] event in
            guard let self else { return }
            switch event {
            case .interrupted:
                Task { [speech] in await speech.stop() }
            case .resumed:
                guard let session, let state = session.state else { return }
                let text = AnnouncementFormatter(names: session.playerNames).resumption(state)
                say(UmpireCall(cue: nil, text: text, priority: .structural))
            }
        }
    }

    private static func isCorrection(_ announcement: Announcement) -> Bool {
        if case .correction = announcement {
            return true
        }
        return false
    }

    private static func isOver(_ state: MatchState) -> Bool {
        if case .complete = state.phase {
            return true
        }
        return false
    }
}

private struct PreRallyKey: Equatable {
    let score: ScoreSnapshot
    let serve: ServeNumber
    let serverCourtSide: CourtSide

    init(_ output: EngineOutput) {
        score = output.state.snapshot
        serve = output.preRally.serve
        serverCourtSide = output.preRally.serverCourtSide
    }
}

extension EnvironmentValues {
    @Entry var umpire: UmpireCoordinator?
}

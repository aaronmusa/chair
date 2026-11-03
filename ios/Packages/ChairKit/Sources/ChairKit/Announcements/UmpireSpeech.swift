//
//  UmpireSpeech.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation

@MainActor
public final class UmpireSpeech: SpeechOutput {
    public var cuesEnabled = true
    public private(set) var isSpeaking = false

    public let synthesizer: any Synthesizing
    private let cues: any CuePlaying
    private var waiting: [UmpireCall] = []
    private var current: UmpireCall?
    private var inWords = false
    private var cueTask: Task<Void, Never>?
    private var worker: Task<Void, Never>?

    public init(
        synthesizer: any Synthesizing,
        cues: any CuePlaying
    ) {
        self.synthesizer = synthesizer
        self.cues = cues
    }

    public func speak(_ calls: [UmpireCall]) async {
        guard let incoming = calls.map(\.priority).max() else { return }
        if incoming == .structural {
            waiting.removeAll { $0.priority != .structural }
            interruptCurrent()
        } else {
            waiting.removeAll { $0.priority == .score }
            if !inWords, current?.priority == .score {
                cancelCue()
            }
        }
        waiting += calls
        startWorker()
    }

    public func speak(_ text: String) async {
        await speak([UmpireCall(cue: nil, text: text, priority: .call)])
    }

    public func stop() async {
        waiting.removeAll()
        cancelCue()
        synthesizer.stopNow()
    }

    public func route() async -> AudioRoute {
        #if os(iOS)
            let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
            let bluetooth: [AVAudioSession.Port] = [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP]
            if outputs.contains(where: bluetooth.contains) {
                return .bluetooth
            }
            if outputs.contains(.headphones) {
                return .headphones
            }
        #endif
        return .speaker
    }

    public func drained() async {
        while let worker {
            await worker.value
        }
    }

    public func warmUp() {
        synthesizer.warmUp()
    }

    private func interruptCurrent() {
        guard current != nil else { return }
        if inWords {
            synthesizer.stopAtWordBoundary()
        } else {
            cancelCue()
        }
    }

    private func cancelCue() {
        guard let cueTask else { return }
        cueTask.cancel()
        let cues = cues
        Task { await cues.stop() }
    }

    private func startWorker() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        isSpeaking = true
        while !waiting.isEmpty {
            let call = waiting.removeFirst()
            current = call
            if await playCue(of: call) {
                inWords = true
                await synthesizer.say(call.text)
                inWords = false
            }
            current = nil
        }
        isSpeaking = false
        worker = nil
    }

    private func playCue(of call: UmpireCall) async -> Bool {
        guard cuesEnabled, let cue = call.cue else { return true }
        let cues = cues
        let task = Task { await cues.play(cue) }
        cueTask = task
        await task.value
        cueTask = nil
        return !task.isCancelled
    }
}

//
//  Synthesizer.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation

@MainActor
public protocol Synthesizing: AnyObject {
    var voiceID: String? { get set }
    var volume: Float { get set }

    func say(_ text: String) async
    func stopAtWordBoundary()
    func stopNow()
    func warmUp()
}

@MainActor
public final class SystemSynthesizer: NSObject, Synthesizing, AVSpeechSynthesizerDelegate {
    public var voiceID: String? {
        didSet { voice = VoiceCatalog.voice(id: voiceID) }
    }

    public var volume: Float = 1
    public var pronunciations: [String: String] = [:]
    public private(set) var startedAt: UInt64?

    private let synthesizer = AVSpeechSynthesizer()
    private var voice = VoiceCatalog.voice(id: nil)
    private var finished: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    override public init() {
        super.init()
        synthesizer.delegate = self
    }

    public func say(_ text: String) async {
        let utterance = utterance(text)
        await withCheckedContinuation { continuation in
            finished[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }
    }

    public func stopAtWordBoundary() {
        synthesizer.stopSpeaking(at: .word)
    }

    public func stopNow() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    public func warmUp() {
        let utterance = AVSpeechUtterance(string: "")
        utterance.voice = voice
        utterance.volume = 0
        synthesizer.speak(utterance)
    }

    public nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didStart _: AVSpeechUtterance
    ) {
        let now = mach_absolute_time()
        Task { @MainActor in self.startedAt = now }
    }

    public nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.resume(id) }
    }

    public nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.resume(id) }
    }

    private func resume(_ id: ObjectIdentifier) {
        finished.removeValue(forKey: id)?.resume()
    }

    private func utterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(attributedString: pronounced(text))
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1
        utterance.volume = volume
        return utterance
    }

    private func pronounced(_ text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        for (word, ipa) in pronunciations {
            var range = (text as NSString).range(of: word)
            while range.location != NSNotFound {
                attributed.addAttribute(NSAttributedString.Key(AVSpeechSynthesisIPANotationAttribute), value: ipa, range: range)
                let next = range.location + range.length
                range = (text as NSString).range(of: word, range: NSRange(location: next, length: (text as NSString).length - next))
            }
        }
        return attributed
    }
}

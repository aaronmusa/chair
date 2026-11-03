//
//  CuedSpeech.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

public struct CuedSpeech: Sendable {
    public let cues: any CuePlaying
    public let speech: any SpeechOutput
    public var cuesEnabled: Bool

    public init(
        cues: any CuePlaying,
        speech: any SpeechOutput,
        cuesEnabled: Bool = true
    ) {
        self.cues = cues
        self.speech = speech
        self.cuesEnabled = cuesEnabled
    }

    public func say(
        _ text: String,
        cue: CueKind?
    ) async {
        if cuesEnabled, let cue {
            await cues.play(cue)
        }
        await speech.speak(text)
    }
}

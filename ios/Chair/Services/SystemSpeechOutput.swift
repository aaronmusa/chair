//
//  SystemSpeechOutput.swift
//  Chair
//
//  Created by Aaron Musa on 10/27/26.
//

import AVFoundation

import ChairKit

final class SystemSpeechOutput: SpeechOutput, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) async {
        synthesizer.speak(AVSpeechUtterance(string: text))
    }

    func stop() async {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func route() async -> AudioRoute {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
        let bluetooth: [AVAudioSession.Port] = [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP]
        if outputs.contains(where: bluetooth.contains) {
            return .bluetooth
        }
        if outputs.contains(.headphones) {
            return .headphones
        }
        return .speaker
    }
}

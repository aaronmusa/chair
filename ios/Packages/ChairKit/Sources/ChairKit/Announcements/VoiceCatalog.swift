//
//  VoiceCatalog.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation

public struct VoiceOption: Equatable, Hashable, Identifiable, Sendable {
    public enum Quality: Int, Sendable, Comparable {
        case standard
        case enhanced
        case premium

        public static func < (
            lhs: Quality,
            rhs: Quality
        ) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public let id: String
    public let name: String
    public let language: String
    public let quality: Quality

    public init(
        id: String,
        name: String,
        language: String,
        quality: Quality
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
    }
}

public enum VoiceCatalog {
    public static func englishVoices() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .map { VoiceOption(id: $0.identifier, name: $0.name, language: $0.language, quality: quality($0.quality)) }
    }

    public static func pick(
        _ id: String?,
        from options: [VoiceOption]
    ) -> VoiceOption? {
        if let id, let chosen = options.first(where: { $0.id == id }) {
            return chosen
        }
        return options.max { rank($0) < rank($1) }
    }

    static func voice(id: String?) -> AVSpeechSynthesisVoice? {
        pick(id, from: englishVoices()).flatMap { AVSpeechSynthesisVoice(identifier: $0.id) }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private static func rank(_ option: VoiceOption) -> (Int, Int) {
        (option.quality.rawValue, option.language == "en-US" ? 1 : 0)
    }

    private static func quality(_ quality: AVSpeechSynthesisVoiceQuality) -> VoiceOption.Quality {
        switch quality {
        case .premium: .premium
        case .enhanced: .enhanced
        default: .standard
        }
    }
}

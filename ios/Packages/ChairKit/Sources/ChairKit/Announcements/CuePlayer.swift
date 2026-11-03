//
//  CuePlayer.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation

public protocol CuePlaying: Sendable {
    func play(_ cue: CueKind) async
    func stop() async
}

@MainActor
public final class CuePlayer: CuePlaying {
    private let players: [CueKind: AVAudioPlayer]

    public init() {
        players = CueKind.allCases.reduce(into: [:]) { players, cue in
            guard let url = cue.url, let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.prepareToPlay()
            players[cue] = player
        }
    }

    public var volume: Float = 1 {
        didSet { players.values.forEach { $0.volume = volume } }
    }

    public func play(_ cue: CueKind) async {
        guard let player = players[cue] else { return }
        let lead = 0.03
        player.currentTime = 0
        let startsAt = player.deviceCurrentTime + lead
        guard player.play(atTime: startsAt) else { return }
        let remaining = startsAt + player.duration - player.deviceCurrentTime
        try? await Task.sleep(for: .seconds(max(0, remaining)))
    }

    public func stop() async {
        players.values.forEach { $0.stop() }
    }
}

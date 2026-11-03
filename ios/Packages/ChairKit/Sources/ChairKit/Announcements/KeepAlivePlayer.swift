//
//  KeepAlivePlayer.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation

@MainActor
public final class KeepAlivePlayer {
    public static let silence = Bundle.module.url(forResource: "silence", withExtension: "caf")

    private var player: AVAudioPlayer?

    public init() {}

    public var isRunning: Bool {
        player?.isPlaying ?? false
    }

    public var playerVolume: Float? {
        player?.volume
    }

    public func start() {
        guard player == nil, let url = Self.silence, let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        self.player = player
    }

    public func stop() {
        player?.stop()
        player = nil
    }
}

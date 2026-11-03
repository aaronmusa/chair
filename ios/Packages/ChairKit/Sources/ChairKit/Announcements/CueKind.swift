//
//  CueKind.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

public enum CueKind: String, Codable, Sendable, CaseIterable {
    case point
    case game
    case set

    public init?(_ announcements: [Announcement]) {
        guard let cue = announcements.compactMap(Self.cue).max(by: { $0.rank < $1.rank }) else { return nil }
        self = cue
    }

    public var url: URL? {
        Bundle.module.url(forResource: rawValue, withExtension: "caf")
    }

    private var rank: Int {
        switch self {
        case .point: 0
        case .game: 1
        case .set: 2
        }
    }

    private static func cue(_ announcement: Announcement) -> CueKind? {
        switch announcement {
        case .gameSetMatch, .gameAndSet, .retired: .set
        case .game: .game
        case .ace, .out, .net, .score, .deuce, .advantage, .fault, .doubleFault, .let, .tiebreakScore: .point
        case .receiverChoosesSide, .changeEnds, .chooseServer, .correction: nil
        }
    }
}

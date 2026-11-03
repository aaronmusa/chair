//
//  PlayerNames.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

public struct PlayerNames: Equatable, Sendable {
    public let names: [PlayerSlot: String]
    public let spokenNames: [PlayerSlot: String]
    public let isDoubles: Bool

    public init(
        _ names: [PlayerSlot: String],
        doubles: Bool,
        spokenNames: [PlayerSlot: String] = [:]
    ) {
        self.names = names
        self.spokenNames = spokenNames
        isDoubles = doubles
    }

    public func spokenName(_ slot: PlayerSlot) -> String {
        spokenNames[slot] ?? names[slot] ?? fallback(slot)
    }

    public func team(_ side: Side) -> String {
        let slots: [PlayerSlot] = side == .a ? [.a1, .a2] : [.b1, .b2]
        guard isDoubles else { return spokenName(slots[0]) }
        return slots.map(spokenName).joined(separator: "–")
    }

    private func fallback(_ slot: PlayerSlot) -> String {
        isDoubles ? "Player \(slot.rawValue)" : "Player \(slot.side.rawValue)"
    }
}

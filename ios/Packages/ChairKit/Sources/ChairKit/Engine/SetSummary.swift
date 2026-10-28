//
//  SetSummary.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public struct TiebreakSummary: Codable, Equatable, Sendable {
    public let a: Int
    public let b: Int

    public init(
        a: Int,
        b: Int
    ) {
        self.a = a
        self.b = b
    }
}

public struct SetSummary: Codable, Equatable, Sendable {
    public let a: Int
    public let b: Int
    public let tiebreak: TiebreakSummary?

    public init(
        a: Int,
        b: Int,
        tiebreak: TiebreakSummary? = nil
    ) {
        self.a = a
        self.b = b
        self.tiebreak = tiebreak
    }
}

public extension MatchState {
    var summary: [SetSummary] {
        var summaries = sets.enumerated().map { index, set in
            SetSummary(a: set.a, b: set.b, tiebreak: completedTiebreaks.indices.contains(index) ? completedTiebreaks[index] : nil)
        }
        if currentSet.a + currentSet.b > 0 {
            summaries.append(SetSummary(a: currentSet.a, b: currentSet.b))
        }
        return summaries
    }

    func setsWon(by side: Side) -> Int {
        sets.count(where: { side == .a ? $0.a > $0.b : $0.b > $0.a })
    }

    var setsToWin: Int {
        rules.sets == .bestOf3 ? 2 : 3
    }

    var isDecidingSet: Bool {
        setsWon(by: .a) == setsToWin - 1 && setsWon(by: .b) == setsToWin - 1
    }
}

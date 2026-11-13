//
//  ScreenshotSeed.swift
//  Chair
//
//  Created by Aaron Musa on 11/14/26.
//

#if DEBUG
    import Foundation
    import SwiftData

    import ChairKit

    enum ScreenshotSeed {
        static let argument = "-ScreenshotSeed"

        private struct Plan {
            let format: MatchFormat
            let names: [PlayerSlot: String]
            let sets: [SetScore]
            let tiebreak: SetScore?
            let current: SetScore?
            let game: SetScore?
            let daysAgo: Int
        }

        static func players(_ arguments: [String]) -> [String: PublicProfile] {
            guard arguments.contains(argument) else { return [:] }
            let players = [
                PublicProfile(id: UUID(), handle: "juan", displayName: "Juan Dela Cruz", level: .intermediate),
                PublicProfile(id: UUID(), handle: "juana", displayName: "Juana Reyes", level: .advanced),
                PublicProfile(id: UUID(), handle: "julio", displayName: "Julio Santos", level: .beginner),
            ]
            return Dictionary(uniqueKeysWithValues: players.map { ($0.handle, $0) })
        }

        static func invites(at now: Date) -> [Invite] {
            [Invite(
                matchID: UUID(),
                ownerHandle: "carlos",
                ownerDisplayName: "Carlos Mendoza",
                playedAt: now.addingTimeInterval(-86400),
                format: .singles,
                status: .completed,
                sets: [SetScore(a: 6, b: 3), SetScore(a: 4, b: 6), SetScore(a: 6, b: 4)]
            )]
        }

        static func seedIfRequested(
            arguments: [String] = ProcessInfo.processInfo.arguments,
            context: ModelContext,
            now: Date = .now
        ) {
            let matches = LocalMatchRepository(context: context)
            let courts = LocalSavedCourtRepository(context: context)
            guard arguments.contains(argument), (try? matches.fetch().isEmpty) ?? false else { return }
            for plan in plans {
                if let match = try? makeMatch(plan, now: now) {
                    try? matches.save(match)
                }
            }
            if let court = makeCourt(now: now) {
                try? courts.save(court)
            }
        }

        private static let plans = [
            Plan(
                format: .singles,
                names: [.a1: "Aaron", .b1: "Juan"],
                sets: [SetScore(a: 6, b: 4)],
                tiebreak: nil,
                current: SetScore(a: 2, b: 3),
                game: SetScore(a: 2, b: 1),
                daysAgo: 0
            ),
            Plan(
                format: .singles,
                names: [.a1: "Aaron", .b1: "Juan"],
                sets: [SetScore(a: 6, b: 4), SetScore(a: 3, b: 6), SetScore(a: 7, b: 5)],
                tiebreak: nil,
                current: nil,
                game: nil,
                daysAgo: 2
            ),
            Plan(
                format: .doubles,
                names: [.a1: "Aaron", .a2: "Mia", .b1: "Lia", .b2: "Ben"],
                sets: [SetScore(a: 6, b: 3), SetScore(a: 6, b: 2)],
                tiebreak: nil,
                current: nil,
                game: nil,
                daysAgo: 6
            ),
            Plan(
                format: .singles,
                names: [.a1: "Aaron", .b1: "Carlos"],
                sets: [SetScore(a: 4, b: 6)],
                tiebreak: SetScore(a: 5, b: 7),
                current: nil,
                game: nil,
                daysAgo: 13
            ),
        ]

        private static func makeMatch(
            _ plan: Plan,
            now: Date
        ) throws -> Match {
            var setup = NewMatchSetup(defaults: MatchDefaults(playerName: "Aaron"))
            setup.format = plan.format
            for (slot, name) in plan.names {
                setup.names[slot] = name
            }
            let start = Calendar.current.date(byAdding: .day, value: -plan.daysAgo, to: now) ?? now
            let match = try setup.makeMatch(at: start.addingTimeInterval(plan.daysAgo == 0 ? -1800 : 0))
            var log = try MatchLog(record: match.record)
            for (index, winner) in winners(plan).enumerated() {
                let event = MatchEvent.pointWon(by: winner, outcome: outcome(index, winner: winner, state: log.state), ending: nil)
                try log.append(TimedEvent(event, at: match.playedAt.addingTimeInterval(Double(index) * 35)))
            }
            match.update(from: log, at: now)
            return match
        }

        private static func winners(_ plan: Plan) -> [Side] {
            var points = plan.sets.flatMap { $0.games.flatMap(points(winning:)) }
            if let tiebreak = plan.tiebreak {
                points += Array(SetScore(a: 6, b: 6).games.flatMap(points(winning:)))
                points += tiebreak.games
            }
            if let current = plan.current {
                points += current.games.flatMap(points(winning:))
            }
            if let game = plan.game {
                points += game.games
            }
            return points
        }

        private static func points(winning side: Side) -> [Side] {
            [side, side.opponent, side, side.opponent, side, side]
        }

        private static func outcome(
            _ index: Int,
            winner: Side,
            state: MatchState
        ) -> PointOutcome? {
            let serving = state.server.side
            switch (index * 7 + 3) % 10 {
            case 0, 1, 2: return .winner
            case 3, 4: return .unforcedError
            case 5: return .forcedError
            case 6: return serving == winner ? .ace : .winner
            case 7: return serving == winner ? .forcedError : .doubleFault
            default: return nil
            }
        }

        private static func makeCourt(now: Date) -> SavedCourt? {
            let keypoints = Dictionary(uniqueKeysWithValues: CourtKeypoint.defaultSet(for: .netPost).map { keypoint in
                let court = keypoint.court
                let depth = court.y + 6
                return (keypoint, CGPoint(x: 960 + 1400 * court.x / depth, y: 280 + 4200 / depth))
            })
            guard let calibration = CourtCalibration(
                keypoints: keypoints,
                placement: .netPost,
                frameSize: CGSize(width: 1920, height: 1080),
                date: now
            ) else { return nil }
            return SavedCourt(name: "Rizal Memorial Court 3", calibration: calibration, lastUsedAt: now, createdAt: now, updatedAt: now)
        }
    }

    private extension SetScore {
        var games: [Side] {
            let (winner, high, low) = a >= b ? (Side.a, a, b) : (Side.b, b, a)
            return Array(repeating: [winner, winner.opponent], count: low).flatMap(\.self)
                + Array(repeating: winner, count: high - low)
        }
    }
#endif

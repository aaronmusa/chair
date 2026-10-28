//
//  MatchSession.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public actor MatchSession {
    public nonisolated let outputs: AsyncStream<EngineOutput>
    public private(set) var log: MatchLog
    private let continuation: AsyncStream<EngineOutput>.Continuation

    public init(log: MatchLog) {
        self.log = log
        (outputs, continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    public init(
        rules: MatchRules,
        format: MatchFormat = .singles
    ) throws {
        try self.init(log: MatchLog(rules: rules, format: format))
    }

    deinit {
        continuation.finish()
    }

    public var state: MatchState {
        log.state
    }

    @discardableResult
    public func apply(_ event: TimedEvent) throws -> EngineOutput {
        let announcements = try log.append(event)
        let output = EngineOutput(state: log.state, announcements: announcements)
        continuation.yield(output)
        return output
    }
}

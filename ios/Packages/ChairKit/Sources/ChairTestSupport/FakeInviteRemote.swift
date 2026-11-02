//
//  FakeInviteRemote.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 11/3/26.
//

#if DEBUG
    import Foundation

    import ChairKit

    public actor FakeInviteRemote: InviteRemote {
        public private(set) var invites: [Invite]
        public private(set) var answers: [UUID: Bool] = [:]

        public init(invites: [Invite] = []) {
            self.invites = invites
        }

        public func pendingInvites() async throws -> [Invite] {
            invites
        }

        public func respond(
            to matchID: UUID,
            accept: Bool
        ) async throws {
            answers[matchID] = accept
            invites.removeAll { $0.matchID == matchID }
        }
    }
#endif

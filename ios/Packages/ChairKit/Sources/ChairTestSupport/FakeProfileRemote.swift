//
//  FakeProfileRemote.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 11/3/26.
//

#if DEBUG
    import Foundation

    import ChairKit

    public actor FakeProfileRemote: ProfileRemote {
        public static let sampleProfile = ProfileRecord(
            id: FakeAuthService.sampleSession.userID,
            handle: "aaron",
            displayName: ProfileRecord.defaultDisplayName
        )

        public private(set) var profile: ProfileRecord?
        public private(set) var claimedNames: [String] = []

        public init(profile: ProfileRecord? = FakeProfileRemote.sampleProfile) {
            self.profile = profile
        }

        public func ownProfile() async throws -> ProfileRecord? {
            profile
        }

        public func claimDisplayName(_ name: String) async throws {
            claimedNames.append(name)
            guard profile?.displayName == ProfileRecord.defaultDisplayName else { return }
            profile?.displayName = name
        }
    }
#endif

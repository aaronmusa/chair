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
        public private(set) var updates: [ProfileRecord] = []
        public var takenHandles: Set<String>
        public var publicProfiles: [String: PublicProfile]
        public var linkedCounts: [UUID: Int]
        public var isOnline = true

        public init(
            profile: ProfileRecord? = FakeProfileRemote.sampleProfile,
            takenHandles: Set<String> = ["aaron_m"],
            publicProfiles: [String: PublicProfile] = [:],
            linkedCounts: [UUID: Int] = [:]
        ) {
            self.profile = profile
            self.takenHandles = takenHandles
            self.publicProfiles = publicProfiles
            self.linkedCounts = linkedCounts
        }

        public func setOnline(_ online: Bool) {
            isOnline = online
        }

        public func update(_ profile: ProfileRecord) async throws {
            guard isOnline else { throw URLError(.notConnectedToInternet) }
            updates.append(profile)
            self.profile = profile
        }

        public func handleAvailable(_ handle: String) async throws -> Bool {
            !takenHandles.contains(handle.lowercased())
        }

        public func publicProfile(handle: String) async throws -> PublicProfile? {
            publicProfiles[handle.lowercased()]
        }

        public func linkedMatchCount(with userID: UUID) async throws -> Int {
            linkedCounts[userID] ?? 0
        }

        public func ownProfile() async throws -> ProfileRecord? {
            guard isOnline else { throw URLError(.notConnectedToInternet) }
            return profile
        }

        public func claimDisplayName(_ name: String) async throws {
            claimedNames.append(name)
            guard profile?.displayName == ProfileRecord.defaultDisplayName else { return }
            profile?.displayName = name
        }
    }
#endif

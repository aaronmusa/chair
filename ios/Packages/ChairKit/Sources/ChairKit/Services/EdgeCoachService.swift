//
//  EdgeCoachService.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

public struct EdgeCoachService: CoachService {
    private let auth: any AuthService
    private let functionsURL: URL
    private let anonKey: String
    private let session: URLSession

    public init(
        auth: any AuthService,
        functionsURL: URL,
        anonKey: String,
        session: URLSession = .shared
    ) {
        self.auth = auth
        self.functionsURL = functionsURL
        self.anonKey = anonKey
        self.session = session
    }

    public func summarize(match: MatchRecord) async throws -> CoachCard {
        guard let signedIn = await auth.currentSession() else { throw CoachError.notSignedIn }

        var request = URLRequest(url: functionsURL.appendingPathComponent("coach"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(signedIn.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(match)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            return try JSONDecoder().decode(CoachCard.self, from: data)
        case 401:
            throw CoachError.notSignedIn
        case 503:
            throw CoachError.unavailable
        default:
            throw CoachError.badResponse(status)
        }
    }
}

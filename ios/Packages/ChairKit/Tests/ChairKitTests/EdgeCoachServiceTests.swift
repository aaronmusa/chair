//
//  EdgeCoachServiceTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class EdgeCoachServiceTests: XCTestCase {
    private let functionsURL = URL(string: "https://chair.test/functions/v1")!

    override func tearDown() {
        StubURLProtocol.respond = nil
        StubURLProtocol.lastRequest = nil
    }

    func testWithNoSessionItThrowsNotSignedInWithoutCallingTheServer() async throws {
        let coach = coach(signedIn: false)
        let record = await MainActor.run { Match.sample().record }

        do {
            _ = try await coach.summarize(match: record)
            XCTFail("expected notSignedIn")
        } catch {
            XCTAssertEqual(error as? CoachError, .notSignedIn)
        }
        XCTAssertNil(StubURLProtocol.lastRequest)
    }

    func testSignedInItPostsTheMatchWithTheUsersToken() async throws {
        StubURLProtocol.respond = { _ in (200, Data(#"{"headline":"Warming up","points":["Later."]}"#.utf8)) }
        let coach = coach(signedIn: true)
        let record = await MainActor.run { Match.sample().record }

        let card = try await coach.summarize(match: record)

        XCTAssertEqual(card, CoachCard(headline: "Warming up", points: ["Later."]))
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://chair.test/functions/v1/coach")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fake-access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon")
    }

    func testAnExpiredTokenMapsToNotSignedIn() async throws {
        StubURLProtocol.respond = { _ in (401, Data()) }
        let coach = coach(signedIn: true)
        let record = await MainActor.run { Match.sample().record }

        do {
            _ = try await coach.summarize(match: record)
            XCTFail("expected notSignedIn")
        } catch {
            XCTAssertEqual(error as? CoachError, .notSignedIn)
        }
    }

    private func coach(signedIn: Bool) -> EdgeCoachService {
        EdgeCoachService(auth: FakeAuthService(signedIn: signedIn), functionsURL: functionsURL, anonKey: "anon", session: stubbedSession())
    }

    private func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        let (status, data) = Self.respond?(request) ?? (500, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

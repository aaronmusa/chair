//
//  WatchMessageTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import XCTest

@testable import ChairKit

final class WatchMessageTests: XCTestCase {
    func testMessagesSurviveTheConnectivityPayload() {
        for message in [WatchMessage.ping, .pong] {
            XCTAssertEqual(WatchMessage(payload: message.payload), message)
        }
    }

    func testAnUnknownPayloadIsIgnored() {
        XCTAssertNil(WatchMessage(payload: ["payload": Data("nonsense".utf8)]))
        XCTAssertNil(WatchMessage(payload: [:]))
    }

    func testThePhoneAnswersPingWithPong() {
        XCTAssertEqual(WatchMessage.defaultReply(to: .ping), .pong)
        XCTAssertNil(WatchMessage.defaultReply(to: .pong))
    }
}

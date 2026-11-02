//
//  WatchMessageTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class WatchMessageTests: XCTestCase {
    func testEveryMessageSurvivesTheEnvelope() {
        let messages: [WatchMessage] = [
            .input(WatchInput(.point(.b))),
            .input(WatchInput(.let)),
            .requestState,
            .endWorkout,
            .state(Self.sampleState),
            .ack(inputID: UUID()),
            .announcement(text: "Fifteen love"),
            .matchEnded,
        ]
        for message in messages {
            XCTAssertEqual(WatchEnvelope.decode(WatchEnvelope(message).data), .message(message))
        }
    }

    func testAnotherProtocolVersionIsReportedAsAMismatch() {
        let data = Data(#"{"protocolVersion":2,"message":{"brandNew":{}}}"#.utf8)

        XCTAssertEqual(WatchEnvelope.decode(data), .versionMismatch(2))
    }

    func testNonsenseIsIgnored() {
        XCTAssertNil(WatchEnvelope.decode(Data("nonsense".utf8)))
        XCTAssertNil(WatchEnvelope.decode(Data(#"{"protocolVersion":1,"message":{"brandNew":{}}}"#.utf8)))
    }

    static let sampleState = WatchState(
        matchID: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
        names: [.a1: "Aaron", .b1: "Juan"],
        mySlot: .a1,
        score: ScoreSnapshot(sets: [], currentSet: SetScore(a: 2, b: 1), currentGame: .standard(a: .thirty, b: .fifteen), server: .a1),
        serverCourtSide: .ad,
        serve: .first,
        phase: .rally
    )
}

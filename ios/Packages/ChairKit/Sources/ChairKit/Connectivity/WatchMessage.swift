//
//  WatchMessage.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

public enum WatchMessage: String, Codable, Sendable {
    case ping
    case pong

    static let payloadKey = "payload"

    var payload: [String: Any] {
        [Self.payloadKey: (try? JSONEncoder().encode(self)) ?? Data()]
    }

    init?(payload: [String: Any]) {
        guard let data = payload[Self.payloadKey] as? Data,
              let message = try? JSONDecoder().decode(WatchMessage.self, from: data) else { return nil }
        self = message
    }

    public static func defaultReply(to message: WatchMessage) -> WatchMessage? {
        message == .ping ? .pong : nil
    }
}

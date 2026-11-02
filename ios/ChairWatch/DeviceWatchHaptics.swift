//
//  DeviceWatchHaptics.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import WatchKit

import ChairKit

struct DeviceWatchHaptics: WatchHaptics {
    func play(_ haptic: WatchHaptic) {
        WKInterfaceDevice.current().play(haptic.type)
    }
}

private extension WatchHaptic {
    var type: WKHapticType {
        switch self {
        case .click: .click
        case .notification: .notification
        case .success: .success
        case .failure: .failure
        }
    }
}

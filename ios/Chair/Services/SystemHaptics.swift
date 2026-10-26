//
//  SystemHaptics.swift
//  Chair
//
//  Created by Aaron Musa on 10/27/26.
//

import UIKit

import ChairKit

struct SystemHaptics: Haptics {
    func play(_ event: HapticEvent) {
        Task { @MainActor in
            switch event {
            case .point:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .game:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .set:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }
}

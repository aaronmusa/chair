//
//  CaptureStatusView.swift
//  Chair
//
//  Created by Aaron Musa on 11/11/26.
//

import SwiftUI
import UIKit

import ChairKit
import ChairUI

struct CaptureStatus: Equatable {
    let symbol: String
    let title: String
    let detail: String?
    let offersSettings: Bool

    init?(_ state: CaptureState) {
        switch state {
        case .idle:
            return nil
        case let .running(format):
            let frameRate = format.frameRate
            guard frameRate < CaptureSession.preferredFrameRate else { return nil }
            self.init(
                symbol: "thermometer.medium",
                title: "Camera at \(frameRate) fps",
                detail: "Slowed down to keep the phone cool"
            )
        case let .interrupted(reason):
            self.init(
                symbol: "pause.circle",
                title: Self.title(for: reason),
                detail: "It picks up again on its own"
            )
        case .pausedForHeat:
            self.init(
                symbol: "thermometer.high",
                title: "Camera paused: phone too hot",
                detail: "Move it into the shade. It restarts once it cools down"
            )
        case .unavailable(.permissionDenied):
            self.init(
                symbol: "camera",
                title: "Camera access is off",
                detail: "Turn it on in Settings so Chair can see the court",
                offersSettings: true
            )
        case .unavailable(.noCamera):
            self.init(symbol: "video.slash", title: "No camera available", detail: nil)
        case .unavailable(.failed):
            self.init(
                symbol: "exclamationmark.triangle",
                title: "The camera couldn't start",
                detail: "Close other camera apps and try again"
            )
        }
    }

    private init(
        symbol: String,
        title: String,
        detail: String?,
        offersSettings: Bool = false
    ) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.offersSettings = offersSettings
    }

    private static func title(for reason: CaptureState.Interruption) -> String {
        switch reason {
        case .otherApp: "Another app is using the camera"
        case .background: "Camera paused while Chair is in the background"
        case .systemPressure: "Camera paused to take load off the phone"
        case .unknown: "Camera paused"
        }
    }
}

struct CaptureStatusView: View {
    let state: CaptureState

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let status = CaptureStatus(state) {
            VStack(alignment: .leading, spacing: Spacing.chair.sm) {
                Label(status.title, systemImage: status.symbol)
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                if let detail = status.detail {
                    Text(detail)
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
                if status.offersSettings {
                    ChairButton("Open Settings", onTap: handleOpenSettings())
                        .accessibilityIdentifier("camera.status.openSettings")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.chair.md)
            .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.large))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camera.status")
        }
    }

    private func handleOpenSettings() -> () -> Void {
        {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        }
    }
}

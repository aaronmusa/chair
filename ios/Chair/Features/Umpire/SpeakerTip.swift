//
//  SpeakerTip.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairUI

struct SpeakerTip: View {
    static let message = "Connect a speaker so everyone hears the umpire"

    var onDismiss: () -> Void = {}

    @State private var routePickerCount = 0

    var body: some View {
        HStack(spacing: Spacing.chair.sm) {
            Text(Self.message)
                .chairFont(.callout)
                .foregroundStyle(Color.chair.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Speaker", systemImage: "hifispeaker", action: handleChooseRoute())
                .labelStyle(.iconOnly)
                .background(RoutePicker(presentCount: routePickerCount).frame(width: 1, height: 1).opacity(0).accessibilityHidden(true))
                .accessibilityLabel("Choose speaker")
                .accessibilityIdentifier("session.speakerTip.route")
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("session.speakerTip.dismiss")
        }
        .padding(Spacing.chair.sm)
        .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.large))
        .padding(.horizontal, Spacing.chair.md)
        .accessibilityIdentifier("session.speakerTip")
    }

    private func handleChooseRoute() -> () -> Void {
        { routePickerCount += 1 }
    }
}

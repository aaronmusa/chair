//
//  WatchSettingsPage.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairUI

struct WatchSettingsPage: View {
    @Binding var holdToScore: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.sm) {
            Toggle("Hold to score", isOn: $holdToScore)
                .chairFont(.headline)
                .toggleStyle(WatchSwitchStyle())
                .accessibilityIdentifier("watch.holdToScore")
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                Text("Lock touch during play")
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                Text(
                    "Press the side button and tap the drop to turn on Water Lock. Crown scoring and Double Tap keep working while it's on."
                )
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("watch.waterLockHint")
        }
        .padding(.horizontal, Spacing.chair.xxs)
    }
}

private struct WatchSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: handleToggle(configuration)) {
            HStack {
                configuration.label
                    .foregroundStyle(Color.chair.ink)
                Spacer(minLength: Spacing.chair.xs)
                Capsule()
                    .fill(configuration.isOn ? Color.chair.success : Color.chair.surfaceRaised)
                    .frame(width: 44, height: 26)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.chair.ink)
                            .padding(3)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }

    private func handleToggle(_ configuration: Configuration) -> () -> Void {
        { configuration.isOn.toggle() }
    }
}

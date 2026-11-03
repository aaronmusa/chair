//
//  UmpireSettingsSection.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct UmpireSettingsSection: View {
    static let silentModeFooter = "With this on, the umpire goes quiet on silent and while the screen is locked."

    @Bindable var settings: UmpireSettings
    let routeName: String
    let voices: [VoiceOption]
    var onPreview: () -> Void = {}
    var onTestCall: () -> Void = {}

    @State private var routePickerCount = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            Toggle("Umpire voice", isOn: $settings.preferences.isEnabled)
                .accessibilityIdentifier("settings.umpire")
            voiceRow
            Picker("Verbosity", selection: $settings.preferences.verbosity) {
                ForEach(Verbosity.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("settings.verbosity")
            Toggle("Sound cues", isOn: $settings.preferences.cuesEnabled)
                .accessibilityIdentifier("settings.soundCues")
            volumeRow
            Toggle("Respect silent mode", isOn: $settings.preferences.respectsSilentMode)
                .accessibilityIdentifier("settings.respectSilentMode")
            Button(action: handleChooseRoute()) {
                LabeledContent("Output", value: routeName)
                    .foregroundStyle(Color.chair.ink)
            }
            .background(RoutePicker(presentCount: routePickerCount).frame(width: 1, height: 1).opacity(0).accessibilityHidden(true))
            .accessibilityIdentifier("settings.outputRoute")
            Button("Test call", action: onTestCall)
                .accessibilityIdentifier("settings.testCall")
        } header: {
            Text("Umpire")
        } footer: {
            Text(Self.silentModeFooter)
        }
    }

    private var voiceRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.chair.xs))
            : AnyLayout(HStackLayout())
        return layout {
            Picker("Voice", selection: $settings.preferences.voiceID) {
                Text("Automatic").tag(String?.none)
                ForEach(voices) { voice in
                    Text(voice.label).tag(Optional(voice.id))
                }
            }
            .accessibilityIdentifier("settings.voice")
            Button("Preview", action: onPreview)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings.voicePreview")
        }
    }

    private var volumeRow: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            LabeledContent("Umpire volume", value: "\(Int((settings.preferences.clampedVolume * 100).rounded())) %")
            Slider(
                value: $settings.preferences.volume,
                in: UmpirePreferences.volumeRange,
                step: 0.05
            )
            .accessibilityLabel("Umpire volume")
            .accessibilityIdentifier("settings.umpireVolume")
        }
    }

    private func handleChooseRoute() -> () -> Void {
        { routePickerCount += 1 }
    }
}

extension Verbosity {
    var title: String {
        switch self {
        case .minimal: "Minimal"
        case .normal: "Normal"
        case .full: "Full"
        }
    }
}

extension VoiceOption {
    var label: String {
        switch quality {
        case .premium: "\(name) (Premium)"
        case .enhanced: "\(name) (Enhanced)"
        case .standard: name
        }
    }
}

//
//  AudioRouting.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import AVFoundation
import AVKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AudioRouting {
    static let speakerName = "Speaker"
    static let disconnectedNote = "Speaker disconnected"

    private(set) var currentRouteName = AudioRouting.speakerName
    private(set) var note: String?

    func refresh(_ route: AVAudioSessionRouteDescription = AVAudioSession.sharedInstance().currentRoute) {
        currentRouteName = Self.name(of: route.outputs.map { ($0.portType, $0.portName) })
    }

    func routeChanged(
        reason: AVAudioSession.RouteChangeReason,
        route: AVAudioSessionRouteDescription = AVAudioSession.sharedInstance().currentRoute
    ) {
        refresh(route)
        note = Self.note(for: reason)
    }

    func clearNote() {
        note = nil
    }

    static func name(of outputs: [(AVAudioSession.Port, String)]) -> String {
        let builtIn: [AVAudioSession.Port] = [.builtInSpeaker, .builtInReceiver]
        guard let output = outputs.first, !builtIn.contains(output.0) else { return speakerName }
        return output.1
    }

    static func note(for reason: AVAudioSession.RouteChangeReason) -> String? {
        reason == .oldDeviceUnavailable ? disconnectedNote : nil
    }
}

struct RoutePicker: UIViewRepresentable {
    var presentCount = 0

    func makeUIView(context _: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.accessibilityElementsHidden = true
        return picker
    }

    func updateUIView(
        _ picker: AVRoutePickerView,
        context: Context
    ) {
        guard presentCount != context.coordinator.presented else { return }
        context.coordinator.presented = presentCount
        picker.subviews.compactMap { $0 as? UIButton }.first?.sendActions(for: .touchUpInside)
    }

    func makeCoordinator() -> Presented {
        Presented(presented: presentCount)
    }

    final class Presented {
        var presented: Int

        init(presented: Int) {
            self.presented = presented
        }
    }
}

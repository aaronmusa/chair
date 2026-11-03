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
    func makeUIView(context _: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(
        _: AVRoutePickerView,
        context _: Context
    ) {}
}

//
//  UmpirePill.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairUI

struct UmpirePill: View {
    let isMuted: Bool
    let routeName: String
    var onToggle: () -> Void = {}

    @State private var routePickerCount = 0

    var body: some View {
        ChairPill(title, isSelected: !isMuted)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
            .onLongPressGesture(perform: handleChooseSpeaker())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, handleToggle())
            .accessibilityHint("Double-tap to mute this match. Touch and hold to choose the speaker.")
            .accessibilityAction(named: "Choose speaker", handleChooseSpeaker())
            .accessibilityIdentifier("session.umpire")
            .background(RoutePicker(presentCount: routePickerCount).frame(width: 1, height: 1).opacity(0.01).accessibilityHidden(true))
    }

    private var title: String {
        isMuted ? "Umpire OFF" : "Umpire ON · \(routeName)"
    }

    private func handleToggle() -> () -> Void {
        { onToggle() }
    }

    private func handleChooseSpeaker() -> () -> Void {
        { routePickerCount += 1 }
    }
}

#if DEBUG
    #Preview("On") {
        UmpirePill(isMuted: false, routeName: "JBL Flip")
    }

    #Preview("Off") {
        UmpirePill(isMuted: true, routeName: "Speaker")
            .preferredColorScheme(.dark)
    }
#endif

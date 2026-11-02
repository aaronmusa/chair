//
//  HoldToScoreButton.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct HoldToScoreButton: View {
    let title: String
    let requiresHold: Bool
    let identifier: String
    let onScore: () -> Void

    @State private var gate = HoldGate()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .contentShape(.capsule)
            .gesture(holdGesture, isEnabled: requiresHold)
            .onTapGesture(perform: handleTap())
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityHint(requiresHold ? "Press and hold to score" : "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, handleAccessibilityScore())
            .accessibilityIdentifier(identifier)
    }

    private var label: some View {
        Text(title)
            .chairFont(.headline)
            .foregroundStyle(gate.isHolding && reduceMotion ? Color.black : Color.chair.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(gate.isHolding && reduceMotion ? Color.chair.accent : Color.chair.surfaceRaised, in: .capsule)
            .overlay {
                if gate.isHolding, !reduceMotion {
                    HoldRing(duration: gate.duration)
                }
            }
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged(handlePress())
            .onEnded(handleRelease())
    }

    private func handlePress() -> (DragGesture.Value) -> Void {
        { _ in gate.begin(onFire: onScore) }
    }

    private func handleRelease() -> (DragGesture.Value) -> Void {
        { _ in gate.end() }
    }

    private func handleTap() -> () -> Void {
        { if !requiresHold { onScore() } }
    }

    private func handleAccessibilityScore() -> () -> Void {
        { onScore() }
    }
}

private struct HoldRing: View {
    let duration: Duration
    @State private var progress: CGFloat = 0

    var body: some View {
        Capsule()
            .trim(from: 0, to: progress)
            .stroke(Color.chair.accent, lineWidth: Stroke.chair.bold * 2)
            .onAppear(perform: handleAppear())
    }

    private func handleAppear() -> () -> Void {
        {
            withAnimation(.linear(duration: duration / .seconds(1))) {
                progress = 1
            }
        }
    }
}

//
//  QRScanOverlay.swift
//  Chair
//
//  Created by Aaron Musa on 11/16/26.
//

import SwiftUI

import ChairUI

struct QRScanOverlay: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Spacing.chair.lg) {
            Spacer()
            Viewfinder()
                .frame(width: 240, height: 240)
                .accessibilityHidden(true)
            Text("Point at the other player's code in their Chair profile")
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.chair.md)
                .padding(.vertical, Spacing.chair.sm)
                .background(Color.chair.surface.opacity(0.85), in: .rect(cornerRadius: Radius.chair.control))
            Spacer()
            ChairButton("Cancel", style: .secondary, onTap: onCancel)
                .accessibilityIdentifier("scanner.cancel")
        }
        .padding(Spacing.chair.md)
    }
}

private struct Viewfinder: View {
    var body: some View {
        ZStack {
            corner(rotation: 0, alignment: .topLeading)
            corner(rotation: 90, alignment: .topTrailing)
            corner(rotation: 180, alignment: .bottomTrailing)
            corner(rotation: 270, alignment: .bottomLeading)
        }
    }

    private func corner(
        rotation: Double,
        alignment: Alignment
    ) -> some View {
        CornerShape()
            .stroke(Color.chair.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .frame(width: 44, height: 44)
            .rotationEffect(.degrees(rotation))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

private struct CornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview {
    QRScanOverlay {}
        .background(Color.chair.surface)
}

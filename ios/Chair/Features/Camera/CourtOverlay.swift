//
//  CourtOverlay.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import CoreGraphics
import SwiftUI

import ChairKit

enum CourtOverlay {
    static let steps = 24

    static func lines(
        through homography: Homography,
        frameSize: CGSize
    ) -> [[CGPoint]] {
        let bounds = CGRect(origin: .zero, size: frameSize).insetBy(dx: -frameSize.width, dy: -frameSize.height)
        return CourtModel.lines.map { segment in
            (0 ... steps).compactMap { step -> CGPoint? in
                let t = Double(step) / Double(steps)
                let court = CourtPoint(
                    x: segment.from.x + (segment.to.x - segment.from.x) * t,
                    y: segment.from.y + (segment.to.y - segment.from.y) * t
                )
                let pixel = homography.toPixel(court)
                guard bounds.contains(pixel), homography.toCourt(pixel) != nil else { return nil }
                return pixel
            }
        }
        .filter { $0.count > 1 }
    }
}

struct CourtLinesOverlay: View {
    let lines: [[CGPoint]]
    let mapping: FrameMapping

    var body: some View {
        Canvas { context, _ in
            let video = CGRect(
                origin: mapping.origin,
                size: CGSize(width: mapping.frameSize.width * mapping.scale, height: mapping.frameSize.height * mapping.scale)
            )
            context.clip(to: Path(video))
            for line in lines {
                var path = Path()
                path.addLines(line.map(mapping.toView))
                context.stroke(path, with: .color(.black.opacity(0.5)), style: StrokeStyle(lineWidth: 4))
                context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension EnvironmentValues {
    @Entry var makeCapture: @Sendable () -> any CaptureSource = { CaptureSession() }
}

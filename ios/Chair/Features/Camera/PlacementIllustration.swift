//
//  PlacementIllustration.swift
//  Chair
//
//  Created by Aaron Musa on 11/11/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct PlacementIllustration: View {
    static let fieldOfView = Angle.degrees(108)

    let placement: CameraPlacement

    var body: some View {
        CourtView(orientation: .landscape)
            .overlay {
                GeometryReader { proxy in
                    Canvas { context, size in
                        draw(in: &context, size: size)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.chair.medium))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Court from above, with the phone \(placement.location) looking \(placement.facing)")
    }

    private func draw(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let coordinate = CourtCoordinate(size: size, orientation: .landscape)
        let phone = coordinate.point(placement.phone)
        let ahead = coordinate.point(CourtPoint(x: placement.phone.x + placement.direction.x, y: placement.phone.y + placement.direction.y))
        let heading = atan2(ahead.y - phone.y, ahead.x - phone.x)
        let reach = hypot(size.width, size.height)
        let half = Self.fieldOfView.radians / 2
        var wedge = Path()
        wedge.move(to: phone)
        wedge.addArc(
            center: phone,
            radius: reach,
            startAngle: .radians(heading - half),
            endAngle: .radians(heading + half),
            clockwise: false
        )
        wedge.closeSubpath()
        context.fill(wedge, with: .color(Color.chair.accent.opacity(0.14)))
        context.stroke(wedge, with: .color(Color.chair.accent.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        let body = CGRect(x: phone.x - 7, y: phone.y - 11, width: 14, height: 22)
        context.fill(Path(roundedRect: body, cornerRadius: 3), with: .color(Color.chair.ink))
    }
}

private extension CameraPlacement {
    var phone: CourtPoint {
        switch self {
        case .netPost: CourtPoint(x: -(CourtDimensions.halfDoublesWidth + 0.9), y: 0)
        case .chair: CourtPoint(x: -(CourtDimensions.halfDoublesWidth + 1.5), y: 0)
        case .baseline: CourtPoint(x: 0, y: -(CourtDimensions.halfLength + 2.5))
        }
    }

    var direction: CourtPoint {
        switch self {
        case .netPost, .chair: CourtPoint(x: 1, y: 0)
        case .baseline: CourtPoint(x: 0, y: 1)
        }
    }

    var location: String {
        switch self {
        case .netPost: "at the net post"
        case .chair: "on the umpire chair"
        case .baseline: "behind the near baseline"
        }
    }

    var facing: String {
        switch self {
        case .netPost, .chair: "across the court"
        case .baseline: "down the court"
        }
    }
}

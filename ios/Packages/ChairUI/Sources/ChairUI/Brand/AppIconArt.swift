//
//  AppIconArt.swift
//  ChairUI
//
//  Created by Aaron Musa on 11/14/26.
//

import SwiftUI

public enum AppIconVariant: String, CaseIterable, Sendable {
    case light
    case dark
    case tinted

    var field: Color {
        switch self {
        case .light: Color.chair.button
        case .dark: Color.chair.onAccent
        case .tinted: .black
        }
    }

    var line: Color {
        switch self {
        case .light, .dark: Color.chair.courtLine
        case .tinted: Color(white: 0.55)
        }
    }

    var ball: Color {
        switch self {
        case .light, .dark: Color.chair.accent
        case .tinted: .white
        }
    }

    var seam: Color {
        switch self {
        case .light, .dark: Color.chair.courtLine
        case .tinted: Color(white: 0.2)
        }
    }

    var skid: Color {
        switch self {
        case .light, .dark: Color.chair.onAccent
        case .tinted: .black
        }
    }
}

public struct AppIconArt: View {
    let variant: AppIconVariant

    public init(_ variant: AppIconVariant = .light) {
        self.variant = variant
    }

    public var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let geometry = LineCallGeometry(side: side)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(variant.field))
            context.fill(geometry.linePath, with: .color(variant.line))
            context.fill(geometry.skidPath, with: .color(variant.skid.opacity(0.55)))
            context.fill(Path(ellipseIn: geometry.ballRect), with: .color(variant.ball))
            var seams = context
            seams.clip(to: Path(ellipseIn: geometry.ballRect))
            seams.stroke(geometry.seamPath, with: .color(variant.seam), lineWidth: geometry.radius * 0.11)
        }
        .environment(\.colorScheme, .light)
        .accessibilityHidden(true)
    }
}

struct LineCallGeometry {
    let side: CGFloat

    var radius: CGFloat {
        side * 0.23
    }

    var centre: CGPoint {
        CGPoint(x: side * 0.54, y: side * 0.45)
    }

    var ballRect: CGRect {
        CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
    }

    private var angle: CGFloat {
        -.pi * 0.16
    }

    private var halfWidth: CGFloat {
        side * 0.055
    }

    private var direction: CGVector {
        CGVector(dx: cos(angle), dy: sin(angle))
    }

    private var normal: CGVector {
        CGVector(dx: -direction.dy, dy: direction.dx)
    }

    private var lineCentre: CGPoint {
        let offset = radius + halfWidth * 0.35
        return CGPoint(x: centre.x + normal.dx * offset, y: centre.y + normal.dy * offset)
    }

    var linePath: Path {
        let reach = side * 2
        let start = CGPoint(x: lineCentre.x - direction.dx * reach, y: lineCentre.y - direction.dy * reach)
        let end = CGPoint(x: lineCentre.x + direction.dx * reach, y: lineCentre.y + direction.dy * reach)
        var path = Path()
        path.move(to: CGPoint(x: start.x + normal.dx * halfWidth, y: start.y + normal.dy * halfWidth))
        path.addLine(to: CGPoint(x: end.x + normal.dx * halfWidth, y: end.y + normal.dy * halfWidth))
        path.addLine(to: CGPoint(x: end.x - normal.dx * halfWidth, y: end.y - normal.dy * halfWidth))
        path.addLine(to: CGPoint(x: start.x - normal.dx * halfWidth, y: start.y - normal.dy * halfWidth))
        path.closeSubpath()
        return path
    }

    var skidPath: Path {
        let contact = CGPoint(x: centre.x + normal.dx * radius, y: centre.y + normal.dy * radius)
        let skid = CGRect(x: -radius * 0.55, y: -radius * 0.09, width: radius * 1.1, height: radius * 0.18)
        let transform = CGAffineTransform(
            translationX: contact.x - direction.dx * radius * 0.25,
            y: contact.y - direction.dy * radius * 0.25
        )
        .rotated(by: angle)
        return Path(ellipseIn: skid).applying(transform)
    }

    var seamPath: Path {
        var path = Path()
        let offset = radius * 1.18
        let seamRadius = radius * 0.82
        path.addEllipse(in: CGRect(
            x: centre.x - offset - seamRadius,
            y: centre.y - seamRadius,
            width: seamRadius * 2,
            height: seamRadius * 2
        ))
        path.addEllipse(in: CGRect(
            x: centre.x + offset - seamRadius,
            y: centre.y - seamRadius,
            width: seamRadius * 2,
            height: seamRadius * 2
        ))
        return path.applying(
            CGAffineTransform(translationX: -centre.x, y: -centre.y)
                .concatenating(CGAffineTransform(rotationAngle: .pi * 0.22))
                .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y))
        )
    }
}

#if DEBUG
    #Preview("Variants") {
        HStack(spacing: 16) {
            ForEach(AppIconVariant.allCases, id: \.self) { variant in
                AppIconArt(variant)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
            }
        }
        .padding()
    }
#endif

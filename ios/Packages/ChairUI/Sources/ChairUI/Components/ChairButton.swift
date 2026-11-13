//
//  ChairButton.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct ChairButton: View {
    public enum Style: CaseIterable, Sendable {
        case primary
        case secondary
        case ghost
        case destructive
    }

    public enum Size: CaseIterable, Sendable {
        case regular
        case large

        var height: CGFloat {
            switch self {
            case .regular: 48
            case .large: 56
            }
        }
    }

    let title: String
    let style: Style
    let size: Size
    let isLoading: Bool
    let onTap: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .regular,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                Text(title)
                    .chairFont(.headline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: size.height)
            .padding(.horizontal, Spacing.chair.md)
        }
        .buttonStyle(ChairButtonStyle(style: style, isLoading: isLoading))
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "Loading" : "")
    }
}

public struct ChairButtonStyle: ButtonStyle {
    let style: ChairButton.Style
    let isLoading: Bool

    public init(_ style: ChairButton.Style) {
        self.style = style
        isLoading = false
    }

    init(
        style: ChairButton.Style,
        isLoading: Bool
    ) {
        self.style = style
        self.isLoading = isLoading
    }

    @Environment(\.isEnabled) private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.chair.control)
        return configuration.label
            .foregroundStyle(foreground)
            .tint(foreground)
            .background(fill(isPressed: configuration.isPressed), in: shape)
            .clipShape(shape)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.12 : 0.28),
                radius: configuration.isPressed ? 1 : 3,
                y: configuration.isPressed ? 1 : 3
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .contentShape(shape)
            .opacity(isEnabled || isLoading ? 1 : 0.35)
    }

    private var foreground: Color {
        switch style {
        case .primary: Color.chair.onAccent
        case .secondary: Color.chair.onButton
        case .ghost: Color.chair.ink
        case .destructive: Color.chair.surface
        }
    }

    private func fill(isPressed: Bool) -> Color {
        switch style {
        case .primary: isPressed ? Color.chair.accentPressed : Color.chair.accent
        case .secondary: Color.chair.button.opacity(isPressed ? 0.85 : 1)
        case .ghost: Color.chair.control.opacity(isPressed ? 0.85 : 1)
        case .destructive: Color.chair.danger.opacity(isPressed ? 0.85 : 1)
        }
    }
}

#if DEBUG
    #Preview("Light") {
        ChairButtonPreview()
    }

    #Preview("Dark") {
        ChairButtonPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("AX5") {
        ChairButtonPreview()
            .environment(\.dynamicTypeSize, .accessibility5)
    }

    struct ChairButtonPreview: View {
        var body: some View {
            VStack(spacing: Spacing.chair.sm) {
                ChairButton("Start match", onTap: {})
                ChairButton("Start match", size: .large, onTap: {})
                ChairButton("Saving", isLoading: true, onTap: {})
                ChairButton("Calibrate court", style: .secondary, onTap: {})
                ChairButton("Skip", style: .ghost, onTap: {})
                ChairButton("End match", style: .destructive, onTap: {})
                ChairButton("Unavailable", onTap: {})
                    .disabled(true)
            }
            .padding(Spacing.chair.md)
            .background(Color.chair.surface)
        }
    }
#endif

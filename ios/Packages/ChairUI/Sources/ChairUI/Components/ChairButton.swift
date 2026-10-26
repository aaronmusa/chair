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

struct ChairButtonStyle: ButtonStyle {
    let style: ChairButton.Style
    let isLoading: Bool

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .tint(foreground)
            .background(background(isPressed: configuration.isPressed))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: Radius.chair.large)
                        .stroke(Color.chair.ink, lineWidth: Stroke.chair.regular)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.chair.large))
            .contentShape(RoundedRectangle(cornerRadius: Radius.chair.large))
            .opacity(isEnabled || isLoading ? 1 : 0.4)
    }

    private var foreground: Color {
        style == .primary ? Color.chair.surface : Color.chair.ink
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        switch style {
        case .primary:
            isPressed ? Color.chair.accentPressed : Color.chair.accent
        case .secondary, .ghost:
            isPressed ? Color.chair.surfaceRaised : Color.clear
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
                ChairButton("Unavailable", onTap: {})
                    .disabled(true)
            }
            .padding(Spacing.chair.md)
            .background(Color.chair.surface)
        }
    }
#endif

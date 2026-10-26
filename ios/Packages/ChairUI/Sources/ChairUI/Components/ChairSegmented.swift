//
//  ChairSegmented.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct ChairSegmented<Value: Hashable>: View {
    public struct Option {
        let value: Value
        let title: String

        public init(
            _ value: Value,
            _ title: String
        ) {
            self.value = value
            self.title = title
        }
    }

    let options: [Option]
    @Binding var selection: Value

    public init(
        _ options: [Option],
        selection: Binding<Value>
    ) {
        precondition((2 ... 4).contains(options.count), "ChairSegmented takes two to four options")
        self.options = options
        _selection = selection
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.chair.xxs) { segments }
            VStack(spacing: Spacing.chair.xxs) { segments }
        }
        .padding(Spacing.chair.xxs)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.chair.large)
                .strokeBorder(Color.chair.outline, lineWidth: Stroke.chair.regular)
        )
    }

    private var segments: some View {
        ForEach(options, id: \.value) { option in
            segment(option)
        }
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option.value == selection
        return Button(action: handleSelect(option.value)) {
            Text(option.title)
                .chairFont(.callout)
                .fixedSize()
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color.chair.surface : Color.chair.ink)
                .frame(maxWidth: .infinity, minHeight: 36)
                .padding(.horizontal, Spacing.chair.xs)
                .background(isSelected ? Color.chair.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Radius.chair.medium))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handleSelect(_ value: Value) -> () -> Void {
        { selection = value }
    }
}

#Preview("Light") {
    ChairSegmentedPreview()
}

#Preview("Dark") {
    ChairSegmentedPreview()
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    ChairSegmentedPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct ChairSegmentedPreview: View {
    @State private var format = "singles"
    @State private var input = "camera"

    var body: some View {
        VStack(spacing: Spacing.chair.sm) {
            ChairSegmented([.init("singles", "Singles"), .init("doubles", "Doubles")], selection: $format)
            ChairSegmented(
                [.init("camera", "Camera"), .init("tap", "Tap"), .init("watch", "Watch"), .init("referee", "Referee")],
                selection: $input
            )
        }
        .padding(Spacing.chair.md)
        .background(Color.chair.surface)
    }
}

//
//  GalleryView.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

#if DEBUG && os(iOS)
    public struct GalleryView: View {
        enum Appearance: String, CaseIterable {
            case system = "System"
            case light = "Light"
            case dark = "Dark"

            var scheme: ColorScheme? {
                switch self {
                case .system: nil
                case .light: .light
                case .dark: .dark
                }
            }
        }

        enum TextSize: String, CaseIterable {
            case standard = "Default"
            case xxxLarge = "XXXL"
            case ax3 = "AX3"
            case ax5 = "AX5"

            var dynamicTypeSize: DynamicTypeSize {
                switch self {
                case .standard: .large
                case .xxxLarge: .xxxLarge
                case .ax3: .accessibility3
                case .ax5: .accessibility5
                }
            }
        }

        @State private var appearance = Appearance.system
        @State private var textSize = TextSize.standard
        @State private var reduceMotion = ProcessInfo.processInfo.arguments.contains("-ReduceMotion")

        @Environment(\.dismiss) private var dismiss

        public init() {}

        public var body: some View {
            NavigationStack {
                ScrollViewReader { proxy in
                    sections
                        .onAppear(perform: handleScrollToStartSection(proxy))
                }
                .background(Color.chair.surface)
                .navigationTitle("Gallery")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done", action: handleDone())
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        settingsMenu
                    }
                }
            }
            .preferredColorScheme(appearance.scheme)
            .environment(\.dynamicTypeSize, textSize.dynamicTypeSize)
            .environment(\.chairReduceMotionOverride, reduceMotion)
        }

        private var sections: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.chair.xxl) {
                    GallerySection("Colours") { ColorTokenGrid() }
                    GallerySection("Type") { TypeScaleList() }
                    GallerySection("Spacing") { MetricTokenList() }
                    GallerySection("Buttons") { GalleryButtons() }
                    GallerySection("Cards") { ChairCardPreview() }
                    GallerySection("Pills") { GalleryPills() }
                    GallerySection("Segmented") { ChairSegmentedPreview() }
                    GallerySection("Rows") { GalleryRows() }
                    GallerySection("Sheet") { ChairSheetPreview() }
                    GallerySection("Countdown ring") { GalleryCountdowns() }
                    GallerySection("Court view") { GalleryCourts() }
                }
                .padding(.vertical, Spacing.chair.md)
            }
        }

        private func handleScrollToStartSection(_ proxy: ScrollViewProxy) -> () -> Void {
            {
                let arguments = ProcessInfo.processInfo.arguments
                guard let flag = arguments.firstIndex(of: "-GallerySection"), arguments.indices.contains(flag + 1) else { return }
                proxy.scrollTo(arguments[flag + 1], anchor: .top)
            }
        }

        private func handleDone() -> () -> Void {
            { dismiss() }
        }

        private var settingsMenu: some View {
            Menu {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Text size", selection: $textSize) {
                    ForEach(TextSize.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("Reduce Motion", isOn: $reduceMotion)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .accessibilityLabel("Gallery settings")
            }
            .accessibilityIdentifier("gallery.settings")
        }
    }

    struct GallerySection<Content: View>: View {
        let title: String
        let content: Content

        init(
            _ title: String,
            @ViewBuilder content: () -> Content
        ) {
            self.title = title
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.chair.sm) {
                Text(title)
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
                    .padding(.horizontal, Spacing.chair.md)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("gallery.section.\(title)")
                content
            }
            .id(title)
        }
    }

    struct GalleryButtons: View {
        var body: some View {
            VStack(spacing: Spacing.chair.sm) {
                ForEach(ChairButton.Style.allCases, id: \.self) { style in
                    ForEach(ChairButton.Size.allCases, id: \.self) { size in
                        ChairButton("\(style) · \(size)", style: style, size: size, onTap: {})
                    }
                }
                ChairButton("Loading", isLoading: true, onTap: {})
                ChairButton("Disabled", onTap: {})
                    .disabled(true)
            }
            .padding(.horizontal, Spacing.chair.md)
        }
    }

    struct GalleryPills: View {
        var body: some View {
            HStack(spacing: Spacing.chair.xs) {
                ChairPill("Filter", onTap: {})
                ChairPill("Selected", isSelected: true, onTap: {})
                ChairPill("Badge")
                ChairPill("Pro", isSelected: true)
            }
            .padding(.horizontal, Spacing.chair.md)
        }
    }

    struct GalleryRows: View {
        var body: some View {
            VStack(spacing: 0) {
                ChairRow("Icon, value, chevron", systemImage: "speaker.wave.2", value: "Daniel", showsChevron: true, onTap: {})
                ChairRow("Value only", value: "Rizal Park")
                ChairRow("Chevron only", showsChevron: true, onTap: {})
                ChairRow("Title only")
            }
        }
    }

    struct GalleryCountdowns: View {
        @State private var startedAt = Date.now

        var body: some View {
            HStack(spacing: Spacing.chair.lg) {
                CountdownRing(startedAt: startedAt, duration: 5, size: .small)
                CountdownRing(startedAt: startedAt, duration: 5)
                CountdownRing(startedAt: startedAt, duration: 10)
                ChairButton("Restart", style: .secondary, onTap: handleRestart())
                    .frame(width: 120)
            }
            .padding(.horizontal, Spacing.chair.md)
        }

        private func handleRestart() -> () -> Void {
            { startedAt = .now }
        }
    }

    struct GalleryCourts: View {
        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.chair.md) {
                HStack(alignment: .top, spacing: Spacing.chair.md) {
                    CourtViewPreview(orientation: .portrait)
                        .frame(width: 110)
                    CourtView(
                        players: [
                            PlayerMarker(id: "Musa", side: .near, position: .behindBaseline(.near, on: .ad, by: 1), role: .server),
                            PlayerMarker(id: "Cruz", side: .near, position: CourtPoint(x: 2.5, y: -3), role: .partner),
                            PlayerMarker(
                                id: "Reyes",
                                side: .far,
                                position: .behindBaseline(.far, on: .ad, by: 0.5, fromCentre: 3),
                                role: .receiver
                            ),
                            PlayerMarker(id: "Lim", side: .far, position: CourtPoint(x: 2.5, y: 3), role: .partner),
                        ],
                        ballMark: BallMark(CourtPoint(x: 4.7, y: 2), call: .out)
                    )
                    .frame(width: 200)
                }
                CourtViewPreview(orientation: .landscape)
            }
            .padding(.horizontal, Spacing.chair.md)
        }
    }

    #Preview {
        GalleryView()
    }
#endif

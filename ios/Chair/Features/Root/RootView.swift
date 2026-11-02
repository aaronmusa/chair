//
//  RootView.swift
//  Chair
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

import ChairUI

struct RootView: View {
    @Environment(\.appRouter) private var router
    @Environment(\.appEnvironment) private var environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    #if DEBUG
        @State private var isShowingGallery = ProcessInfo.processInfo.arguments.contains("-ShowGallery")
    #endif

    var body: some View {
        content
            .tint(Color.chair.accent)
            .onOpenURL(perform: handleOpenURL())
        #if DEBUG
            .fullScreenCover(isPresented: $isShowingGallery) {
                GalleryView()
            }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        @Bindable var router = router
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(AppSection.allCases, selection: optionalSelection) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                        .accessibilityIdentifier("sidebar.\(section.rawValue)")
                }
                .navigationTitle("Chair")
            } detail: {
                NavigationStack {
                    sectionView(router.selectedSection)
                }
            }
            .sheet(item: $router.presentedMatch) { match in
                MatchSessionPlaceholder(match: match)
                    .presentationSizing(.page)
                    .interactiveDismissDisabled()
            }
        } else {
            TabView(selection: $router.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Tab(section.title, systemImage: section.systemImage, value: section) {
                        NavigationStack {
                            sectionView(section)
                        }
                    }
                    .accessibilityIdentifier("tab.\(section.rawValue)")
                }
            }
            .fullScreenCover(item: $router.presentedMatch) { match in
                MatchSessionPlaceholder(match: match)
            }
        }
    }

    private var optionalSelection: Binding<AppSection?> {
        Binding(
            get: { router.selectedSection },
            set: { router.selectedSection = $0 ?? router.selectedSection }
        )
    }

    @ViewBuilder
    private func sectionView(_ section: AppSection) -> some View {
        switch section {
        case .settings:
            SettingsView(viewModel: SettingsViewModel(environment: environment))
        default:
            PlaceholderView(section: section)
        }
    }

    private func handleOpenURL() -> (URL) -> Void {
        { url in _ = router.handle(url) }
    }
}

#Preview("Compact") {
    RootView()
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("Regular", traits: .landscapeLeft) {
    RootView()
        .environment(\.horizontalSizeClass, .regular)
}

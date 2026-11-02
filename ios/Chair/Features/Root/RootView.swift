//
//  RootView.swift
//  Chair
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct RootView: View {
    @Environment(\.appRouter) private var router
    @Environment(\.appEnvironment) private var environment
    @Environment(\.matchRepository) private var repository
    @Environment(\.inviteCenter) private var invites
    @Environment(\.watchBridge) private var watchBridge
    @State private var firstMatchPrompt = FirstMatchPrompt.make()
    @Environment(\.syncCoordinator) private var sync
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    #if DEBUG
        @State private var isShowingGallery = ProcessInfo.processInfo.arguments.contains("-ShowGallery")
    #endif

    var body: some View {
        content
            .tint(Color.chair.accent)
            .onOpenURL(perform: handleOpenURL())
            .task(handleRefreshInvites())
            .onChange(of: sync?.lastSyncedAt, handleSynced())
            .sheet(isPresented: isShowingInvites) {
                if let invites {
                    InvitesView(center: invites)
                }
            }
            .sheet(isPresented: isShowingPublicProfile) {
                NavigationStack {
                    PublicProfileView(
                        viewModel: PublicProfileViewModel(handle: router.publicProfileHandle ?? "", environment: environment)
                    )
                }
            }
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
                        .badge(badge(for: section))
                        .tag(section)
                        .accessibilityIdentifier("sidebar.\(section.rawValue)")
                }
                .navigationTitle("Chair")
            } detail: {
                stack(router.selectedSection)
            }
            .sheet(item: $router.presentedMatch) { match in
                sessionView(match)
                    .presentationSizing(.page)
                    .interactiveDismissDisabled()
            }
        } else {
            TabView(selection: $router.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Tab(section.title, systemImage: section.systemImage, value: section) {
                        stack(section)
                    }
                    .badge(badge(for: section))
                    .accessibilityIdentifier("tab.\(section.rawValue)")
                }
            }
            .fullScreenCover(item: $router.presentedMatch) { match in
                sessionView(match)
            }
        }
    }

    private func withInvitesBanner(_ content: some View) -> some View {
        content.safeAreaInset(edge: .top) {
            if let invites, !invites.invites.isEmpty {
                InvitesBanner(center: invites)
                    .padding(.horizontal, Spacing.chair.md)
            }
        }
    }

    private func badge(for section: AppSection) -> Int {
        section == .matches ? invites?.count ?? 0 : 0
    }

    private var isShowingInvites: Binding<Bool> {
        Binding(
            get: { invites?.isShowingInvites ?? false },
            set: { invites?.isShowingInvites = $0 }
        )
    }

    private func handleRefreshInvites() -> @MainActor @Sendable () async -> Void {
        { [invites] in await invites?.refresh() }
    }

    private func handleSynced() -> (Date?, Date?) -> Void {
        { [invites] _, _ in Task { await invites?.refresh() } }
    }

    private var isShowingPublicProfile: Binding<Bool> {
        Binding(
            get: { router.publicProfileHandle != nil },
            set: { if !$0 { router.publicProfileHandle = nil } }
        )
    }

    private var optionalSelection: Binding<AppSection?> {
        Binding(
            get: { router.selectedSection },
            set: { router.selectedSection = $0 ?? router.selectedSection }
        )
    }

    @ViewBuilder
    private func stack(_ section: AppSection) -> some View {
        @Bindable var router = router
        if section == .play {
            NavigationStack(path: $router.playPath) {
                sectionView(section)
                    .navigationDestination(for: PlayDestination.self, destination: playDestination)
            }
        } else {
            NavigationStack {
                sectionView(section)
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: AppSection) -> some View {
        switch section {
        case .play:
            withInvitesBanner(PlayHomeScreen(
                viewModel: PlayHomeViewModel(repository: repository, clock: environment.clock),
                actions: PlayHomeActions(
                    onNewMatch: handleNewMatch(),
                    onServeTraining: handleServeTraining(),
                    onQuickScore: handleNewMatch(),
                    onOpenMatch: handleOpenMatch()
                )
            ))
        case .matches:
            withInvitesBanner(MatchesScreen(viewModel: MatchListViewModel(repository: repository)))
        case .settings:
            SettingsView(viewModel: SettingsViewModel(environment: environment))
        default:
            PlaceholderView(section: section)
        }
    }

    private func playDestination(_ destination: PlayDestination) -> some View {
        NewMatchView(
            viewModel: NewMatchViewModel(
                defaults: environment.matchDefaults.load(),
                repository: repository,
                clock: environment.clock,
                auth: environment.auth
            ),
            onStart: handleStartSession()
        )
    }

    private func sessionView(_ match: PresentedMatch) -> some View {
        MatchSessionView(viewModel: watchBridge?.session(for: match.id) ?? standaloneSession(match))
    }

    private func standaloneSession(_ match: PresentedMatch) -> MatchSessionViewModel {
        MatchSessionViewModel(
            matchID: match.id,
            repository: repository,
            clock: environment.clock,
            asksHowPointEnded: environment.matchDefaults.load().asksHowPointEnded,
            auth: environment.auth,
            firstMatchPrompt: firstMatchPrompt
        )
    }

    private func handleServeTraining() -> () -> Void {
        { router.selectedSection = .train }
    }

    private func handleOpenMatch() -> (UUID) -> Void {
        { matchID in router.presentSession(for: matchID) }
    }

    private func handleNewMatch() -> () -> Void {
        { router.showNewMatch() }
    }

    private func handleStartSession() -> (UUID) -> Void {
        { matchID in router.startSession(for: matchID) }
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

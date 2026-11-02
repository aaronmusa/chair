//
//  PlayHomeScreen.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit

struct PlayHomeScreen: View {
    @State private var viewModel: PlayHomeViewModel
    let actions: PlayHomeActions

    init(
        viewModel: PlayHomeViewModel,
        actions: PlayHomeActions
    ) {
        _viewModel = State(initialValue: viewModel)
        self.actions = actions
    }

    var body: some View {
        PlayHomeView(model: viewModel.model, actions: actions)
            .task(handleObserve())
    }

    private func handleObserve() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in await viewModel.observe() }
    }
}

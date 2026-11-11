//
//  PlacementView.swift
//  Chair
//
//  Created by Aaron Musa on 11/11/26.
//

import SwiftUI

import ChairKit
#if DEBUG
    import ChairTestSupport
#endif
import ChairUI

struct PlacementView: View {
    @State private var viewModel: PlacementViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: PlacementViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.chair.lg) {
                PlacementIllustration(placement: viewModel.placement)
                    .accessibilityIdentifier("placement.illustration")
                checklist
                Text("Higher is better: the far lines are thin from the net.")
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
                alternatives
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(Spacing.chair.md)
            .frame(maxWidth: .infinity)
        }
        .background(Color.chair.surface)
        .navigationTitle("Phone setup")
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onChange(of: scenePhase, handleScenePhase())
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.sm) {
            Text(viewModel.placement.title)
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
            ForEach(viewModel.placement.checklist, id: \.self) { item in
                Label {
                    Text(item)
                        .chairFont(.body)
                        .foregroundStyle(Color.chair.ink)
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Color.chair.accent)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("placement.checklist")
    }

    private var alternatives: some View {
        DisclosureGroup(isExpanded: $viewModel.isShowingAlternatives) {
            VStack(alignment: .leading, spacing: Spacing.chair.sm) {
                ForEach(CameraPlacement.allCases, id: \.self, content: placementRow)
            }
            .padding(.top, Spacing.chair.sm)
        } label: {
            Text("All placements")
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
        }
        .tint(Color.chair.ink)
        .accessibilityIdentifier("placement.alternatives")
    }

    private func placementRow(_ placement: CameraPlacement) -> some View {
        let isSelected = viewModel.placement == placement
        return Button(action: handleSelect(placement)) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.chair.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.chair.accent : Color.chair.inkSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text(placement.title)
                        .chairFont(.body)
                        .foregroundStyle(Color.chair.ink)
                    Text(placement.tradeOff)
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("placement.option.\(placement.rawValue)")
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.chair.sm) {
            if viewModel.permission == .denied {
                CaptureStatusView(state: .unavailable(.permissionDenied))
            } else {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.danger)
                }
                ChairButton("Open camera", size: .large, onTap: handleOpenCamera())
                    .disabled(viewModel.isOpening)
                    .accessibilityIdentifier("placement.openCamera")
            }
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, Spacing.chair.md)
        .padding(.vertical, Spacing.chair.sm)
        .frame(maxWidth: .infinity)
        .background(Color.chair.surface)
    }

    private func handleSelect(_ placement: CameraPlacement) -> () -> Void {
        { viewModel.placement = placement }
    }

    private func handleOpenCamera() -> () -> Void {
        { Task { await viewModel.openCamera() } }
    }

    private func handleScenePhase() -> (ScenePhase, ScenePhase) -> Void {
        { _, phase in
            if phase == .active {
                viewModel.refreshPermission()
            }
        }
    }
}

#if DEBUG
    #Preview("Net post") {
        NavigationStack {
            PlacementView(viewModel: PlacementViewModel(
                matchID: UUID(),
                repository: nil,
                authorization: FakeCameraAuthorization(.notDetermined),
                onOpen: { _ in }
            ))
        }
    }

    #Preview("Denied dark") {
        NavigationStack {
            PlacementView(viewModel: PlacementViewModel(
                matchID: UUID(),
                repository: nil,
                authorization: FakeCameraAuthorization(.denied),
                onOpen: { _ in }
            ))
        }
        .preferredColorScheme(.dark)
    }
#endif

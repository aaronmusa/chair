//
//  CalibrationView.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import SwiftUI
import UIKit

import ChairKit
import ChairUI

struct CalibrationView: View {
    static let handleSize: CGFloat = 44
    static let loupeSize: CGFloat = 100
    static let loupeZoom: CGFloat = 3

    @State private var viewModel: CalibrationViewModel
    @State private var dragging: CourtKeypoint?
    @Environment(\.scenePhase) private var scenePhase
    private let isLive: Bool

    init(
        viewModel: CalibrationViewModel,
        isLive: Bool = true
    ) {
        _viewModel = State(initialValue: viewModel)
        self.isLive = isLive
    }

    var body: some View {
        GeometryReader { proxy in
            let mapping = FrameMapping(viewSize: proxy.size, frameSize: viewModel.frameSize)
            ZStack(alignment: .topLeading) {
                CameraPreview(capture: viewModel.capture, still: viewModel.still)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local, perform: handleTap(mapping))
                    .accessibilityHidden(true)
                maskOverlay(mapping)
                courtOverlay(mapping)
                ForEach(viewModel.order, id: \.self) { keypoint in
                    if let point = viewModel.keypoints[keypoint] {
                        handle(keypoint, at: mapping.toView(point), mapping: mapping)
                    }
                }
                if let dragging, let point = viewModel.keypoints[dragging] {
                    loupe(around: point, mapping: mapping)
                }
            }
            .coordinateSpace(.named("calibration"))
        }
        .background(Color.black)
        .ignoresSafeArea()
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await handleAppear() }
        .onDisappear(perform: handleDisappear())
        .onAppear(perform: handleOrientation(.landscapeRight))
        .onChange(of: scenePhase, handleScenePhase())
        .environment(\.colorScheme, .dark)
    }

    private var topBar: some View {
        VStack(spacing: Spacing.chair.xs) {
            HStack(spacing: Spacing.chair.xxs) {
                ForEach(viewModel.order, id: \.self) { keypoint in
                    Circle()
                        .fill(viewModel.keypoints[keypoint] != nil ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.keypoints.count) of \(viewModel.order.count) points placed")
            Text(instruction)
                .chairFont(.callout)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("calibration.instruction")
        }
        .padding(.vertical, Spacing.chair.xs)
        .padding(.horizontal, Spacing.chair.md)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(.top, Spacing.chair.xs)
    }

    private var instruction: String {
        if let status = CaptureStatus(viewModel.captureState) {
            return status.title
        }
        if let next = viewModel.nextKeypoint, viewModel.keypoints.count < Homography.minimumPoints || !viewModel.canContinue {
            return "Tap the \(next.label(for: viewModel.placement).lowercased())"
        }
        if let refusal = viewModel.refusal {
            return refusal.message
        }
        return "Drag any point onto its line, then tap Next"
    }

    private var bottomBar: some View {
        HStack(spacing: Spacing.chair.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.chair.xs) {
                    ForEach(viewModel.pills) { pill in
                        Text(pill.title)
                            .chairFont(.callout)
                            .padding(.horizontal, Spacing.chair.sm)
                            .padding(.vertical, Spacing.chair.xxs)
                            .foregroundStyle(pill.level == .warning ? Color.black : Color.white)
                            .background(pillColour(pill.level), in: Capsule())
                            .accessibilityIdentifier("calibration.pill.\(pill.id)")
                    }
                }
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.danger)
            }
            #if DEBUG
                Button("Mask", systemImage: "square.grid.3x3", action: handleToggleMask())
                    .labelStyle(.iconOnly)
                    .tint(.white)
            #endif
            if let next = viewModel.nextKeypoint, viewModel.keypoints.count >= Homography.minimumPoints {
                Button("Skip", action: handleSkip(next))
                    .tint(.white)
                    .accessibilityIdentifier("calibration.skip")
            }
            Button("Redo", action: viewModel.redo)
                .tint(.white)
                .accessibilityIdentifier("calibration.redo")
            ChairButton("Next", onTap: viewModel.finish)
                .frame(width: 120)
                .disabled(!viewModel.canContinue)
                .accessibilityIdentifier("calibration.next")
        }
        .padding(.horizontal, Spacing.chair.md)
        .padding(.vertical, Spacing.chair.xs)
        .background(.black.opacity(0.55))
    }

    @ViewBuilder
    private func maskOverlay(_ mapping: FrameMapping) -> some View {
        if viewModel.isShowingMask, let mask = viewModel.debugMask {
            Image(decorative: mask, scale: 1)
                .resizable()
                .frame(width: viewModel.frameSize.width * mapping.scale, height: viewModel.frameSize.height * mapping.scale)
                .offset(x: mapping.origin.x, y: mapping.origin.y)
                .blendMode(.screen)
                .opacity(0.7)
                .allowsHitTesting(false)
        }
    }

    private func courtOverlay(_ mapping: FrameMapping) -> some View {
        CourtLinesOverlay(lines: viewModel.projectedLines, mapping: mapping)
    }

    private func handle(
        _ keypoint: CourtKeypoint,
        at point: CGPoint,
        mapping: FrameMapping
    ) -> some View {
        let isNext = keypoint == viewModel.nextKeypoint
        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .background(Circle().fill(Color.black.opacity(0.25)))
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: .black, radius: 1)
            }
            .frame(width: Self.handleSize, height: Self.handleSize)
            if dragging == keypoint || isNext {
                Text(keypoint.label(for: viewModel.placement))
                    .chairFont(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .background(.black.opacity(0.6), in: Capsule())
                    .fixedSize()
            }
        }
        .position(x: point.x, y: point.y + (dragging == keypoint || isNext ? 10 : 0))
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("calibration")).onChanged(handleDrag(keypoint, mapping))
            .onEnded(handleDragEnded()))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keypoint.label(for: viewModel.placement))
        .accessibilityIdentifier("calibration.handle.\(keypoint.rawValue)")
    }

    @ViewBuilder
    private func loupe(
        around point: CGPoint,
        mapping: FrameMapping
    ) -> some View {
        if let still = viewModel.still {
            let zoomed = mapping.scale * Self.loupeZoom
            Image(decorative: still, scale: 1)
                .resizable()
                .frame(width: viewModel.frameSize.width * zoomed, height: viewModel.frameSize.height * zoomed)
                .offset(x: Self.loupeSize / 2 - point.x * zoomed, y: Self.loupeSize / 2 - point.y * zoomed)
                .frame(width: Self.loupeSize, height: Self.loupeSize, alignment: .topLeading)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                .overlay(Image(systemName: "plus").foregroundStyle(Color.chair.accent))
                .padding(Spacing.chair.md)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private extension CalibrationView {
    func pillColour(_ level: ReadinessPill.Level) -> Color {
        switch level {
        case .ok: Color.chair.success.opacity(0.85)
        case .neutral: Color.white.opacity(0.2)
        case .warning: Color.chair.warning
        }
    }

    func handleTap(_ mapping: FrameMapping) -> (CGPoint) -> Void {
        { location in viewModel.place(at: mapping.toFrame(location)) }
    }

    func handleDrag(
        _ keypoint: CourtKeypoint,
        _ mapping: FrameMapping
    ) -> (DragGesture.Value) -> Void {
        { value in
            dragging = keypoint
            viewModel.move(keypoint, to: mapping.toFrame(value.location))
        }
    }

    func handleDragEnded() -> (DragGesture.Value) -> Void {
        { _ in dragging = nil }
    }

    func handleSkip(_ keypoint: CourtKeypoint) -> () -> Void {
        { viewModel.skip(keypoint) }
    }

    func handleToggleMask() -> () -> Void {
        { viewModel.isShowingMask.toggle() }
    }

    func handleAppear() async {
        guard isLive else { return }
        await viewModel.start()
    }

    func handleDisappear() -> () -> Void {
        {
            guard isLive else { return }
            Task { await viewModel.stop() }
            handleOrientation(.portrait)()
        }
    }

    func handleOrientation(_ orientation: UIInterfaceOrientationMask) -> () -> Void {
        {
            guard isLive else { return }
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            scene?.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { _ in }
        }
    }

    func handleScenePhase() -> (ScenePhase, ScenePhase) -> Void {
        { _, phase in
            guard isLive else { return }
            switch phase {
            case .background: Task { await viewModel.stop() }
            case .active: Task { await viewModel.start() }
            default: break
            }
        }
    }
}

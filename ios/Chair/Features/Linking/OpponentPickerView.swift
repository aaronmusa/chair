//
//  OpponentPickerView.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import VisionKit

import ChairKit
import ChairUI

struct OpponentPickerView: View {
    @State private var viewModel: OpponentPickerViewModel
    @State private var isScanning = false
    @Environment(\.appRouter) private var router
    @Environment(\.dismiss) private var dismiss

    init(viewModel: OpponentPickerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        TextField("Search by handle", text: $viewModel.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("picker.search")
                        if Self.canScan {
                            Button("Scan a player's QR code", systemImage: "qrcode.viewfinder", action: handleScan())
                                .accessibilityIdentifier("picker.scan")
                        }
                    }
                    Section {
                        ForEach(viewModel.results, id: \.id) { profile in
                            Button(action: handlePick(profile)) { row(profile) }
                                .accessibilityIdentifier("picker.result.\(profile.handle)")
                        }
                        if let message = viewModel.message {
                            Text(message)
                                .chairFont(.callout)
                                .foregroundStyle(Color.chair.inkSecondary)
                        }
                    }
                }
                .listRowBackground(Color.chair.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(Color.chair.surface)
            .navigationTitle("Link a player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: handleCancel())
                }
            }
            .sheet(isPresented: $isScanning) {
                QRScannerView(onScan: handleScanned())
                    .ignoresSafeArea()
            }
        }
        .onAppear(perform: handlePicking(true))
        .onDisappear(perform: handlePicking(false))
        .onChange(of: router.pickedHandle, handlePickedHandle())
    }

    private func row(_ profile: PublicProfile) -> some View {
        HStack(spacing: Spacing.chair.sm) {
            AvatarView(name: profile.displayName, size: 40)
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                Text(profile.displayName)
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                Text("@\(profile.handle)")
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    static var canScan: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private func handleCancel() -> () -> Void {
        { dismiss() }
    }

    private func handlePicking(_ isPicking: Bool) -> () -> Void {
        { [router] in router.isPickingOpponent = isPicking }
    }

    private func handlePick(_ profile: PublicProfile) -> () -> Void {
        { [viewModel] in viewModel.pick(profile) }
    }

    private func handleScan() -> () -> Void {
        { isScanning = true }
    }

    private func handleScanned() -> (String) -> Void {
        { [viewModel] payload in
            isScanning = false
            Task { await viewModel.scanned(payload) }
        }
    }

    private func handlePickedHandle() -> (String?, String?) -> Void {
        { [viewModel, router] _, handle in
            guard let handle else { return }
            router.pickedHandle = nil
            Task { await viewModel.pick(handle: handle) }
        }
    }
}

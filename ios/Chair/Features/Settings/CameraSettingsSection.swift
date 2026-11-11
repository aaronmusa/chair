//
//  CameraSettingsSection.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import Foundation
import Observation
import SwiftUI
import UIKit

import ChairKit
import ChairUI

@MainActor
@Observable
final class CameraSettings {
    static let locationKey = "chair.camera.usesLocation"

    private let defaults: UserDefaults

    var usesLocation: Bool {
        didSet { defaults.set(usesLocation, forKey: Self.locationKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        usesLocation = defaults.bool(forKey: Self.locationKey)
    }

    var locator: (any CourtLocating)? {
        usesLocation ? SystemCourtLocator() : nil
    }
}

struct CameraSettingsSection: View {
    @Bindable var settings: CameraSettings
    let courts: (any SavedCourtRepository)?

    var body: some View {
        Section {
            Toggle("Use location to find courts", isOn: $settings.usesLocation)
                .accessibilityIdentifier("settings.camera.location")
            if let courts {
                NavigationLink {
                    SavedCourtsView(repository: courts)
                } label: {
                    Text("Saved courts")
                }
                .accessibilityIdentifier("settings.camera.savedCourts")
            }
        } header: {
            Text("Camera")
        } footer: {
            Text("With location on, Chair checks where you are once when you calibrate, to place the points from a court you saved nearby.")
        }
    }
}

struct SavedCourtsView: View {
    let repository: any SavedCourtRepository

    @State private var courts: [SavedCourt] = []
    @State private var renaming: SavedCourt?
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            if courts.isEmpty {
                Text("Courts you save after calibrating show here.")
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            ForEach(courts) { court in
                Button(action: handleRename(court)) {
                    row(court)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("savedCourts.row")
            }
            .onDelete(perform: handleDelete())
        }
        .scrollContentBackground(.hidden)
        .background(Color.chair.surface)
        .navigationTitle("Saved courts")
        .task { reload() }
        .alert("Rename court", isPresented: renameBinding) {
            TextField("Name", text: $name)
            Button("Save", action: handleSaveName())
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn't do that", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func row(_ court: SavedCourt) -> some View {
        HStack(spacing: Spacing.chair.sm) {
            thumbnail(court)
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                Text(court.name)
                    .chairFont(.body)
                    .foregroundStyle(Color.chair.ink)
                Text(detail(court))
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func thumbnail(_ court: SavedCourt) -> some View {
        if let file = court.thumbnailFile, let image = UIImage(contentsOfFile: CourtThumbnails.url(for: file).path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(16 / 9, contentMode: .fill)
                .frame(width: 64, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: Radius.chair.medium))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: Radius.chair.medium)
                .fill(Color.chair.surfaceRaised)
                .frame(width: 64, height: 36)
                .accessibilityHidden(true)
        }
    }

    private func detail(_ court: SavedCourt) -> String {
        let placement = court.calibration?.placement.title ?? "Camera"
        guard let used = court.lastUsedAt else { return placement }
        return "\(placement) · last used \(used.formatted(date: .abbreviated, time: .omitted))"
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func reload() {
        courts = (try? repository.fetch()) ?? []
    }

    private func handleRename(_ court: SavedCourt) -> () -> Void {
        {
            name = court.name
            renaming = court
        }
    }

    private func handleSaveName() -> () -> Void {
        {
            guard let court = renaming else { return }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                errorMessage = "A court needs a name."
                return
            }
            court.name = trimmed
            do {
                try repository.save(court)
            } catch {
                errorMessage = "Couldn't rename the court. Try again."
            }
            renaming = nil
            reload()
        }
    }

    private func handleDelete() -> (IndexSet) -> Void {
        { offsets in
            for index in offsets {
                let court = courts[index]
                CourtThumbnails.remove(court.thumbnailFile)
                do {
                    try repository.delete(court)
                } catch {
                    errorMessage = "Couldn't delete the court. Try again."
                }
            }
            reload()
        }
    }
}

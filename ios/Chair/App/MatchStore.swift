//
//  MatchStore.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import SwiftData
import SwiftUI

import ChairKit

enum MatchStore {
    static func makeContainer(arguments: [String] = ProcessInfo.processInfo.arguments) -> ModelContainer {
        if let container = try? ChairContainer.make(inMemory: arguments.contains("-UseFakes")) {
            #if DEBUG
                ScreenshotSeed.seedIfRequested(arguments: arguments, context: container.mainContext)
            #endif
            return container
        }
        do {
            return try ChairContainer.make(inMemory: true)
        } catch {
            fatalError("Could not create the match store: \(error)")
        }
    }
}

extension EnvironmentValues {
    @Entry var matchRepository: (any MatchRepository)?
    @Entry var syncCoordinator: SyncCoordinator?
    @Entry var profileRepository: ProfileRepository?
    @Entry var savedCourtRepository: (any SavedCourtRepository)?
}

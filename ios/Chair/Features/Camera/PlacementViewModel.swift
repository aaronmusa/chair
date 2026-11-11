//
//  PlacementViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class PlacementViewModel {
    var placement = CameraPlacement.netPost
    var isShowingAlternatives = false
    private(set) var permission: CameraPermission
    private(set) var isOpening = false
    private(set) var errorMessage: String?

    let matchID: UUID
    private let repository: (any MatchRepository)?
    private let authorization: any CameraAuthorizing
    private let onOpen: (UUID) -> Void

    init(
        matchID: UUID,
        repository: (any MatchRepository)?,
        authorization: any CameraAuthorizing,
        onOpen: @escaping (UUID) -> Void
    ) {
        self.matchID = matchID
        self.repository = repository
        self.authorization = authorization
        self.onOpen = onOpen
        permission = authorization.status()
    }

    var alternatives: [CameraPlacement] {
        CameraPlacement.allCases.filter { $0 != .netPost }
    }

    func refreshPermission() {
        permission = authorization.status()
    }

    func openCamera() async {
        guard !isOpening else { return }
        isOpening = true
        defer { isOpening = false }
        errorMessage = nil
        if authorization.status() == .notDetermined {
            _ = await authorization.request()
        }
        permission = authorization.status()
        guard permission == .authorized else { return }
        guard let repository, let match = try? repository.fetch().first(where: { $0.remoteID == matchID }) else {
            errorMessage = "Couldn't find this match. Go back and start it again."
            return
        }
        do {
            match.cameraPlacementValue = placement
            try repository.save(match)
            onOpen(matchID)
        } catch {
            errorMessage = "Couldn't save the placement. Try again."
        }
    }
}

extension CameraPlacement {
    var title: String {
        switch self {
        case .netPost: "Net post"
        case .baseline: "Behind the baseline"
        case .chair: "Umpire chair"
        }
    }

    var tradeOff: String {
        switch self {
        case .netPost: "Best view of the far side. The deep near alleys are out of view"
        case .baseline: "Sees the whole court, but depth at the far baseline is less accurate"
        case .chair: "Higher, so the far lines are clearer. Needs a chair at the net"
        }
    }

    var checklist: [String] {
        let mount = "1.5–2 m up where you can: a fence post, tripod or net-post clamp. Never under 1 m"
        switch self {
        case .netPost:
            return [
                "Landscape, 0.5× lens",
                mount,
                "Far sideline and both far corners in frame",
                "Net post clear of the near sideline",
            ]
        case .baseline:
            return ["Landscape, 0.5× lens", mount, "All four corners in frame", "Centred behind the near baseline"]
        case .chair:
            return ["Landscape, 0.5× lens", "On the umpire chair at the net", "Far sideline and both far corners in frame"]
        }
    }
}

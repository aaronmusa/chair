//
//  ExampleViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 10/26/26.
//

import Observation

@Observable
final class ExampleViewModel {
    private(set) var tapCount = 0

    var title: String {
        tapCount == 0 ? "Chair" : "Tapped \(tapCount)×"
    }

    func tap() {
        tapCount += 1
    }
}

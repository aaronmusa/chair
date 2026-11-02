//
//  WatchSnapshot.swift
//  ChairWatchTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import SnapshotTesting

enum WatchSize: String, CaseIterable {
    case mm41 = "41mm"
    case mm45 = "45mm"

    var size: CGSize {
        switch self {
        case .mm41: CGSize(width: 176, height: 215)
        case .mm45: CGSize(width: 198, height: 242)
        }
    }
}

@MainActor
func assertWatchSnapshot(
    of view: some View,
    named name: String,
    dynamicTypeSize: DynamicTypeSize = .large,
    sizes: [WatchSize] = WatchSize.allCases,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    for watch in sizes {
        let content = view
            .frame(width: watch.size.width, height: watch.size.height)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.uiImage, let png = image.pngData() else {
            XCTFail("Could not render \(name) at \(watch.rawValue)", file: file, line: line)
            continue
        }
        assertSnapshot(
            of: png,
            as: .png,
            named: "\(name)-\(watch.rawValue)",
            file: file,
            testName: testName,
            line: line
        )
    }
}

extension Snapshotting where Value == Data, Format == Data {
    static var png: Snapshotting {
        Snapshotting(pathExtension: "png", diffing: Snapshotting.data.diffing)
    }
}

//
//  StreamCollector.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

@MainActor
final class StreamCollector<Element: Sendable> {
    private(set) var items: [Element] = []
    private var task: Task<Void, Never>?

    init(
        _ stream: AsyncStream<Element>,
        onEach: @escaping @MainActor (Element) async -> Void = { _ in }
    ) {
        task = Task { [weak self] in
            for await item in stream {
                self?.items.append(item)
                await onEach(item)
            }
        }
    }

    func value(after delay: Duration) async -> [Element] {
        try? await Task.sleep(for: delay)
        return items
    }

    func value(
        count: Int,
        timeout: Duration = .seconds(5)
    ) async -> [Element] {
        let deadline = ContinuousClock.now + timeout
        while items.count < count, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return items
    }
}

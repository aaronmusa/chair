//
//  FakeSavedCourtRepository.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 11/11/26.
//

#if DEBUG
    import Foundation

    import ChairKit

    @MainActor
    public final class FakeSavedCourtRepository: SavedCourtRepository {
        public private(set) var courts: [SavedCourt]
        private var continuations: [UUID: AsyncStream<[SavedCourtRecord]>.Continuation] = [:]

        public init(courts: [SavedCourt] = []) {
            self.courts = courts
        }

        public func save(_ court: SavedCourt) throws {
            if !courts.contains(where: { $0 === court }) {
                courts.append(court)
            }
            publish()
        }

        public func fetch() throws -> [SavedCourt] {
            courts
        }

        public func observe() -> AsyncStream<[SavedCourtRecord]> {
            let (stream, continuation) = AsyncStream.makeStream(of: [SavedCourtRecord].self)
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(courts.compactMap(\.record))
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
            return stream
        }

        public func delete(_ court: SavedCourt) throws {
            courts.removeAll { $0 === court }
            publish()
        }

        public func clearLocal() throws {
            courts = []
            publish()
        }

        private func publish() {
            let records = courts.compactMap(\.record)
            continuations.values.forEach { $0.yield(records) }
        }
    }
#endif

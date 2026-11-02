//
//  InMemoryAccountStore.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 11/3/26.
//

#if DEBUG
    import Foundation

    import ChairKit

    public final class InMemoryAccountStore: AccountStore {
        public var lastUserID: UUID?

        public init(lastUserID: UUID? = nil) {
            self.lastUserID = lastUserID
        }
    }
#endif

//
//  InMemoryModelContainer.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftData

import ChairKit

// swiftlint:disable:next identifier_name
public func InMemoryModelContainer() throws -> ModelContainer {
    try ChairContainer.make(inMemory: true)
}

//
//  TestBundle.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 10/27/26.
//

#if DEBUG
    import Foundation

    public enum TestBundle {
        public enum FixtureError: Error, Equatable {
            case missing(String)
        }

        public static func data(
            named name: String,
            in bundle: Bundle
        ) throws -> Data {
            let fixture = URL(fileURLWithPath: name)
            guard let url = bundle.url(
                forResource: fixture.deletingPathExtension().lastPathComponent,
                withExtension: fixture.pathExtension.isEmpty ? "json" : fixture.pathExtension,
                subdirectory: "Fixtures"
            ) else {
                throw FixtureError.missing(name)
            }
            return try Data(contentsOf: url)
        }

        public static func decode<T: Decodable>(
            _ type: T.Type,
            named name: String,
            in bundle: Bundle,
            decoder: JSONDecoder = JSONDecoder()
        ) throws -> T {
            try decoder.decode(type, from: data(named: name, in: bundle))
        }
    }
#endif

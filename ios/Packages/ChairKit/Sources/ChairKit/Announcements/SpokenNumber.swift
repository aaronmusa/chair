//
//  SpokenNumber.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

enum SpokenNumber {
    private static let units = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
    ]
    private static let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
    private static let ordinals = ["first", "second", "third", "fourth", "fifth"]

    static func words(_ number: Int) -> String {
        guard number >= 0, number < 100 else { return String(number) }
        guard number >= 20 else { return units[number] }
        let unit = number % 10
        return unit == 0 ? tens[number / 10] : "\(tens[number / 10])-\(units[unit])"
    }

    static func games(_ number: Int) -> String {
        number == 0 ? "love" : words(number)
    }

    static func ordinal(_ number: Int) -> String? {
        ordinals.indices.contains(number - 1) ? ordinals[number - 1] : nil
    }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

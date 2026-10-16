//
//  AppVersion.swift
//  Vitals
//
//  Created by gd182 on 10/15/26.
//

nonisolated struct AppVersion: Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ text: String) {
        let version = text.hasPrefix("v")
            ? String(text.dropFirst())
            : text

        let components = version.split(
            separator: ".",
            omittingEmptySubsequences: false
        )

        guard components.count == 3 else {
            return nil
        }

        var numbers: [Int] = []

        for component in components {
            guard !component.isEmpty,
                  component.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  let number = Int(component) else {
                return nil
            }

            numbers.append(number)
        }

        major = numbers[0]
        minor = numbers[1]
        patch = numbers[2]
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }

        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }

        return lhs.patch < rhs.patch
    }
}
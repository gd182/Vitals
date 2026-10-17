//
//  UpdatePreferences.swift
//  Vitals
//
//  Created by gd182 on 10/16/26.
//

import Foundation

@MainActor
final class UpdatePreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var automaticChecksEnabled: Bool {
        get {
            defaults.bool(forKey: "automaticUpdateChecks")
        }
        set {
            defaults.set(newValue, forKey: "automaticUpdateChecks")
        }
    }

    var lastAttempt: Date? {
        defaults.object(forKey: "lastAutomaticUpdateAttempt") as? Date
    }

    func recordAttempt(at date: Date) {
        defaults.set(date, forKey: "lastAutomaticUpdateAttempt")
    }
}
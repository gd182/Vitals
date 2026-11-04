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
    var checkInterval: UpdateCheckInterval {
        get {
            guard let rawValue = defaults.object(forKey: "automaticUpdateCheckInterval") as? Int,
                let interval = UpdateCheckInterval(rawValue: rawValue) else {
                return .daily
            }
            return interval
        }
        set {
            defaults.set(newValue.rawValue, forKey: "automaticUpdateCheckInterval")
        }
    }

    var lastSuccessfulCheck: Date? {
        defaults.object(forKey: "lastSuccessfulUpdateCheck") as? Date
    }

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

    func recordSuccessfulCheck(at date: Date) {
        defaults.set(date, forKey: "lastSuccessfulUpdateCheck")
    }
}
//
//  LanguageManager.swift
//  Vitals
//
//  Created by Алексей on 8/25/26.
//

import SwiftUI
import Combine

class LanguageManager: ObservableObject {
    @Published var locale: Locale
    @AppStorage("appLanguage") var appLanguage: String = "en" {
        didSet {
            locale = Locale(identifier: appLanguage)
        }
    }
    
    init() {
        locale = Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? "en")
    }
}

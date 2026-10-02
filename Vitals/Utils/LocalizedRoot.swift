//
//  LocalizedRoot.swift
//  Vitals
//
//  Created by Алексей on 8/25/26.
//

import SwiftUI

struct LocalizedRoot<Content: View>: View {
    @ObservedObject var langManager : LanguageManager
    @AppStorage("appearance") private var appearance = "system"
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .environment(\.locale, langManager.locale)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
    }
}

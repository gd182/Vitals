//
//  LocalizedRoot.swift
//  Vitals
//
//  Created by Алексей on 8/25/26.
//

import SwiftUI

struct LocalizedRoot<Content: View>: View {
    @ObservedObject var langManager : LanguageManager
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content().environment(\.locale, langManager.locale)
    }
}

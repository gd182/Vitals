//
//  DashboardBlock.swift
//  Vitals
//
//  Created by Алексей on 6/29/26.
//

import SwiftUI

struct DashboardBlock: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let content: BlockContent
    var hasSettings: Bool
}

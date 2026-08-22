//
//  DashboardConfig.swift
//  Vitals
//
//  Created by Алексей on 6/29/26.
//

import SwiftUI
import Combine

class DashboardConfig : ObservableObject {
    var namespace: String
    @Published var order: [String] = [] {
        didSet {
            UserDefaults.standard.set(order, forKey: "\(namespace).order")
        }
    }
    

    init(namespace: String) {
        self.namespace = namespace
        self.order = UserDefaults.standard.stringArray(forKey: "\(namespace).order") ?? []
    }
    
    func isVisible(id: String) -> Bool {
        UserDefaults.standard.object(forKey: "\(namespace).\(id).visible") as? Bool ?? true
    }
    
    func setVisible(id: String, _ isVisible: Bool) {
        UserDefaults.standard.set(isVisible, forKey: "\(namespace).\(id).visible")
        objectWillChange.send()

    }
    
    func moveUp(id: String) {
        guard let idx = order.firstIndex(of: id), idx > 0 else { return }
        order.swapAt(idx, idx - 1)
    }

    func moveDown(id: String) {
        guard let idx = order.firstIndex(of: id), idx < order.count - 1 else { return }
        order.swapAt(idx, idx + 1)
    }
}

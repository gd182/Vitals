//
//  DashboardConfig.swift
//  Vitals
//
//  Created by Алексей on 6/29/26.
//

import SwiftUI
import Combine

class DashboardConfig : ObservableObject {
    private let defaults: UserDefaults
    var namespace: String
    @Published var order: [String] = [] {
        didSet {
            defaults.set(order, forKey: "\(namespace).order")
        }
    }
    

    init(namespace: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.namespace = namespace
        self.order = defaults.stringArray(forKey: "\(namespace).order") ?? []
    }
    
    func isVisible(id: String) -> Bool {
        defaults.object(forKey: "\(namespace).\(id).visible") as? Bool ?? true
    }
    
    func setVisible(id: String, _ isVisible: Bool) {
        defaults.set(isVisible, forKey: "\(namespace).\(id).visible")
        objectWillChange.send()

    }
    
    func moveUp(id: String) {
        guard let idx = order.firstIndex(of: id), idx > 0 else { return }
        order.swapAt(idx, idx - 1)
    }

    func reset(ids: [String]) {
        for id in ids {
            defaults.removeObject(forKey: "\(namespace).\(id).visible")
        }
        order = ids
    }

    func moveDown(id: String) {
        guard let idx = order.firstIndex(of: id), idx < order.count - 1 else { return }
        order.swapAt(idx, idx + 1)
    }

    func reconcile(ids: [String]) {
        var updated = order.filter { ids.contains($0) }
        updated.append(contentsOf: ids.filter { !updated.contains($0) })
        if order != updated { order = updated }
    }
}

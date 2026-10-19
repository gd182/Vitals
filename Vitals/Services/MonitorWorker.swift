//
//  MonitorWorker.swift
//  Vitals
//
//  Created by gd182 on 18/15/26.
//

import Foundation

// Safety: collector operations run only on this serial queue. Actions must not
// retain the collector or pass it or its internal pointers to other contexts.
nonisolated final class MonitorWorker : @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.vitals.monitor.worker",
        qos: .utility
    )

    private let monitor = SystemMonitor()

    func perform(
        _ action: @escaping @Sendable (SystemMonitor) -> Void
    ) {
        queue.async { [self] in
            action(self.monitor)
        }
    }
}

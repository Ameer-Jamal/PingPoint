//
//  NetworkMonitor.swift
//  PingPoint
//
//  Created by Ameer Jamal on 11/2/23.
//

import Foundation
import Network

class NetworkMonitor {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var statusChangeHandler: ((Bool) -> Void)?

    init(statusChangeHandler: @escaping (Bool) -> Void) {
        self.monitor = NWPathMonitor()
        self.statusChangeHandler = statusChangeHandler
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                self?.statusChangeHandler?(isConnected)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

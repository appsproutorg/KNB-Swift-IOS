//
//  NetworkMonitor.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import Foundation
import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case none
    }
    
    init() {
        // Don't start monitoring immediately - let the view start it
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isConnected = path.status == .satisfied
            
            let connectionType: ConnectionType
            if path.usesInterfaceType(.wifi) {
                connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = .ethernet
            } else if path.status == .satisfied {
                connectionType = .unknown
            } else {
                connectionType = .none
            }
            
            DispatchQueue.main.async {
                self.isConnected = isConnected
                self.connectionType = connectionType
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}


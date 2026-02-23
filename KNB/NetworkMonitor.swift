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
    
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var recheckTimer: Timer?
    private var isMonitoring = false
    
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

    deinit {
        recheckTimer?.invalidate()
        recheckTimer = nil
        monitor?.cancel()
        monitor = nil
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        let newMonitor = NWPathMonitor()
        monitor = newMonitor
        
        newMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { @MainActor in
                self.apply(path: path)
            }
        }
        newMonitor.start(queue: queue)
        
        // Fallback poll every 10s so stale state gets corrected quickly.
        recheckTimer?.invalidate()
        recheckTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard let path = self.monitor?.currentPath else { return }
                self.apply(path: path)
            }
        }
        
        // Immediate refresh right after start.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            guard let path = self.monitor?.currentPath else { return }
            self.apply(path: path)
        }
    }
    
    func stopMonitoring() {
        recheckTimer?.invalidate()
        recheckTimer = nil
        monitor?.cancel()
        monitor = nil
        isMonitoring = false
    }
    
    private func apply(path: NWPath) {
        let connected = path.status == .satisfied
        let type = mapConnectionType(from: path)

        // Publish only when needed to keep UI updates clean.
        if isConnected != connected {
            isConnected = connected
        }
        if connectionType != type {
            connectionType = type
        }
    }
    
    private func mapConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        }
        if path.usesInterfaceType(.cellular) {
            return .cellular
        }
        if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        if path.status == .satisfied {
            return .unknown
        }
        return .none
    }
}

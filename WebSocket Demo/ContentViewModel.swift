//
//  ContentViewModel.swift
//  WebSocket Demo
//
//  Created by Pushpsen Airekar on 15/05/25.
//

import Foundation
import Starscream
import Network

@Observable
class ContentViewModel {
    
    // MARK: - Enums & Properties
    enum ConnectionState : Equatable {
        case idle, connecting, connected, disconnected, retrying(Int), failed(String)
    }
    
    var socket: WebSocket
    var connectionState: ConnectionState = .idle
    var messages: [String] = []
    var localError: String?
    
    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    private let monitor = NWPathMonitor()
    private var heartbeatTimer: Timer?
    private var shouldReconnectWhenReachable = false
    
    // MARK: - Init
    
    init(socket: WebSocket) {
        self.socket = socket
        startNetworkMonitor()
    }
    
    // MARK: - Setup & Lifecycle
    
    func setupSubscription() {
        socket.delegate = self
        connectSocket()
    }
    
    private func connectSocket() {
        guard case .connected = connectionState else {
            connectionState = .connecting
            socket.connect()
            return
        }
    }
    
    func disconnect() {
        socket.disconnect()
        stopHeartbeat()
    }
    
    func retryConnectionManually() {
        reconnectAttempts = 0
        localError = nil
        connectionState = .connecting
        connectSocket()
    }
    
    // MARK: - Heartbeat
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] timer in
            guard let self = self, self.connectionState == .connected else {
                timer.invalidate()
                return
            }
            self.socket.write(ping: Data())
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                print("🟢 Network is reachable")
                
                if self.shouldReconnectWhenReachable,
                   case .disconnected = self.connectionState {
                    self.shouldReconnectWhenReachable = false
                    print("📶 Network restored. Reconnecting now.")
                    self.retryConnectionManually()
                }
                
            } else {
                print("🔴 Network is not reachable")
                self.connectionState = .failed("No internet connection")
                self.shouldReconnectWhenReachable = true
            }
        }
        
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    // MARK: - Reconnection Logic
    
    private func attemptReconnection() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .failed("Unable to reconnect after \(maxReconnectAttempts) attempts")
            return
        }
        
        reconnectAttempts += 1
        let backoff = min(pow(1.0, Double(reconnectAttempts)), 3.0)
        let jitter = Double.random(in: 0.5...1.5)
        let delay = backoff * jitter
        
        connectionState = .retrying(reconnectAttempts)
        print("🔁 Reconnecting in \(String(format: "%.1f", delay)) seconds (attempt \(reconnectAttempts))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connectSocket()
        }
    }
    
    // MARK: - Message Handling
    
    func sendMessage() {
        guard connectionState == .connected else { return }
        let message = "Hey, there! + \(Date.currentTimeStamp)"
        socket.write(string: message)
    }
    
    func addMessage(_ message: String) {
        messages = messages + [message] // triggers UI update
    }
    
    private func handleError(_ error: Error?) {
        let message = error?.localizedDescription ?? "Unknown error"
        localError = message
        connectionState = .failed(message)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.localError = nil
        }
    }
}

// MARK: - WebSocketDelegate

extension ContentViewModel: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: any WebSocketClient) {
        switch event {
        case .connected(let headers):
            reconnectAttempts = 0
            connectionState = .connected
            print("✅ Connected: \(headers)")
            startHeartbeat()
            
        case .disconnected(let reason, let code):
            connectionState = .disconnected
            print("⚠️ Disconnected: \(reason) (code: \(code))")
            stopHeartbeat()
            
            if monitor.currentPath.status != .satisfied {
                shouldReconnectWhenReachable = true
            } else {
                attemptReconnection()
            }
            
        case .text(let text):
            print("📩 Received: \(text)")
            addMessage(text)
            
        case .binary(let data):
            print("📦 Received binary data (\(data.count) bytes)")
            
        case .ping(_), .pong(_):
            break
            
        case .viabilityChanged(_), .reconnectSuggested(_), .peerClosed:
            break
            
        case .cancelled:
            connectionState = .disconnected
            print("❌ Cancelled by client")
            stopHeartbeat()
            attemptReconnection()
            
        case .error(let error):
            handleError(error)
            stopHeartbeat()
            
            if monitor.currentPath.status != .satisfied {
                shouldReconnectWhenReachable = true
            } else {
                attemptReconnection()
            }
        }
    }
}

// MARK: - Timestamp Helper

extension Date {
    static var currentTimeStamp: Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

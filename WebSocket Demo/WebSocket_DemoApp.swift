//
//  WebSocket_DemoApp.swift
//  WebSocket Demo
//
//  Created by Pushpsen Airekar on 15/05/25.
//

import SwiftUI
import Starscream

@main
struct WebSocket_DemoApp: App {
    
    var body: some Scene {
        WindowGroup {
            let viewModel = ContentViewModel(
                socket: WebSocket(request: URLRequest(url: URL(string: "https://echo.websocket.org")!))
            )
            ContentView(
                viewModel: viewModel
            )
        }
    }
}

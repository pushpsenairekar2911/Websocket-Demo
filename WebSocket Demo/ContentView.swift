import SwiftUI

struct ContentView: View {
    @State var viewModel: ContentViewModel
    @State var message: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    // MARK: - Connection Indicator
                    connectionIndicatorView()
                    
                    // MARK: - Connection
                    Section("Connection") {
                        startWebsocketButton()
                        stopWebsocketButton()
                    }
                    
                    // MARK: - Send Message
                    Section("Send Message") {
                        writeMessageButton()
                    }
                    
                    // MARK: - Receive Message
                    Section {
                        messageView()
                    } header: {
                        Text("Receive Message")
                    } footer: {
                        Text("Made with love by Pushpsen Airekar ♥️.")
                            .font(.footnote)
                    }
                    
                    // MARK: - Error View
                    if let error = viewModel.localError {
                        errorView(error: error)
                    }
                }
                
                // MARK: - Chat Bar
                buildChatView()
            }
            .navigationTitle("Websocket Demo")
            .task {
                viewModel.setupSubscription()
            }
        }
    }
}

// MARK: - Connection Buttons

extension ContentView {
    
    private var isConnected: Bool {
        viewModel.connectionState == .connected
    }
    
    private func startWebsocketButton() -> some View {
        Button("Start Websocket") {
            viewModel.retryConnectionManually()
        }
        .disabled(isConnected || viewModel.connectionState == .connecting)
    }
    
    private func stopWebsocketButton() -> some View {
        Button("Stop Websocket") {
            viewModel.disconnect()
        }
        .disabled(!isConnected)
    }
    
    private func writeMessageButton() -> some View {
        Button("Send Message") {
            viewModel.sendMessage()
        }
        .disabled(!isConnected)
    }
}

// MARK: - Message UI

extension ContentView {
    
    private func messageView() -> some View {
        List(viewModel.messages, id: \.self) { message in
            Text(message)
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if case .failed(let message) = viewModel.connectionState {
                Text("❌ Error: \(message)")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Button("Retry Connection") {
                    viewModel.retryConnectionManually()
                }
                .padding(.top, 4)
            }
            
            Text("⚠️ \(error)")
                .foregroundColor(.orange)
                .font(.caption)
        }
    }
    
    private func connectionIndicatorView() -> some View {
        HStack {
            Text("Status:")
            Spacer()
            switch viewModel.connectionState {
            case .connected:
                Text("Connected 🟢")
            case .connecting:
                Text("Connecting ⏳")
            case .disconnected:
                Text("Disconnected 🔴")
            case .retrying(let attempt):
                Text("Retrying (\(attempt)) 🔁")
            case .failed:
                Text("Failed ❌")
            case .idle:
                Text("Idle ⚪️")
            }
        }
    }
    
    private func buildChatView() -> some View {
        VStack {
            Spacer()
            HStack(alignment: .center) {
                ZStack(alignment: .center) {
                    HStack {
                        TextField("Enter Message", text: $message)
                            .frame(minHeight: 30, alignment: .leading)
                            .font(.system(size: 16))
                            .cornerRadius(6.0)
                            .multilineTextAlignment(.leading)
                            .padding(6)
                            .padding(.horizontal, 10)
                            .submitLabel(.done)
                        
                        Button {
                            viewModel.addMessage(message)
                            message = ""
                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                            haptic.impactOccurred()
                        } label: {
                            Image(systemName: "arrow.forward")
                                .tint(.white)
                        }
                        .padding(.trailing, 5)
                    }
                }
            }.padding(16)
             .offset(y: -4)
        }.frame(height: 64)
         .background(Color(.systemFill))
    }
}

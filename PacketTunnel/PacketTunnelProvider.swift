//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  VPN extension that creates an outbound tunnel to bypass iOS device isolation
//

import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var tunnelConnection: NWTCPConnection?
    private var serverAddress: String = ""
    private var serverPort: UInt16 = 9876
    private let log = OSLog(subsystem: "ca.robertxiao.socks-ios.PacketTunnel", category: "tunnel")
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel...", log: log, type: .info)
        
        // Get server configuration from protocol configuration
        guard let providerConfig = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
              let serverAddr = providerConfig["serverAddress"] as? String else {
            os_log("Missing server configuration", log: log, type: .error)
            completionHandler(NSError(domain: "PacketTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing server configuration"]))
            return
        }
        
        serverAddress = serverAddr
        if let port = providerConfig["serverPort"] as? UInt16 {
            serverPort = port
        }
        
        os_log("Connecting to server: %{public}@:%d", log: log, type: .info, serverAddress, serverPort)
        
        // Create tunnel network settings
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverAddress)
        
        // Configure IPv4 settings - use a private IP range for the tunnel
        let ipv4Settings = NEIPv4Settings(addresses: ["10.8.0.2"], subnetMasks: ["255.255.255.0"])
        
        // Route all traffic through the tunnel
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        
        // Exclude the server address from the tunnel (so we can reach it)
        let excludedRoute = NEIPv4Route(destinationAddress: serverAddress, subnetMask: "255.255.255.255")
        ipv4Settings.excludedRoutes = [excludedRoute]
        
        tunnelNetworkSettings.ipv4Settings = ipv4Settings
        
        // Configure DNS
        tunnelNetworkSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        
        // Set MTU
        tunnelNetworkSettings.mtu = 1400
        
        // Apply network settings
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                os_log("Failed to set tunnel network settings: %{public}@", log: self?.log ?? OSLog.default, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }
            
            // Connect to the server
            self?.connectToServer(completionHandler: completionHandler)
        }
    }
    
    private func connectToServer(completionHandler: @escaping (Error?) -> Void) {
        let endpoint = NWHostEndpoint(hostname: serverAddress, port: String(serverPort))
        
        tunnelConnection = createTCPConnection(to: endpoint, enableTLS: false, tlsParameters: nil, delegate: nil)
        
        tunnelConnection?.addObserver(self, forKeyPath: "state", options: .new, context: nil)
        
        // Wait for connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            
            if self.tunnelConnection?.state == .connected {
                os_log("Connected to server successfully", log: self.log, type: .info)
                self.startPacketTunneling()
                completionHandler(nil)
            } else {
                os_log("Failed to connect to server", log: self.log, type: .error)
                completionHandler(NSError(domain: "PacketTunnel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to server"]))
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "state" {
            if let connection = object as? NWTCPConnection {
                os_log("Connection state changed: %d", log: log, type: .debug, connection.state.rawValue)
            }
        }
    }
    
    private func startPacketTunneling() {
        // Read packets from the virtual interface and send to server
        packetFlow.readPackets { [weak self] packets, protocols in
            self?.handleOutboundPackets(packets: packets, protocols: protocols)
            // Continue reading
            self?.startPacketTunneling()
        }
        
        // Read packets from server and write to virtual interface
        readFromServer()
    }
    
    private func handleOutboundPackets(packets: [Data], protocols: [NSNumber]) {
        guard let connection = tunnelConnection, connection.state == .connected else { return }
        
        for packet in packets {
            // Prepend packet length (4 bytes) for framing
            var length = UInt32(packet.count).bigEndian
            var framedPacket = Data(bytes: &length, count: 4)
            framedPacket.append(packet)
            
            connection.write(framedPacket) { error in
                if let error = error {
                    os_log("Error writing packet: %{public}@", log: self.log, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    private func readFromServer() {
        guard let connection = tunnelConnection, connection.state == .connected else { return }
        
        // Read packet length first (4 bytes)
        connection.readMinimumLength(4, maximumLength: 4) { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                os_log("Error reading from server: %{public}@", log: self.log, type: .error, error.localizedDescription)
                return
            }
            
            guard let lengthData = data, lengthData.count == 4 else {
                self.readFromServer()
                return
            }
            
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // Read the packet data
            connection.readMinimumLength(Int(length), maximumLength: Int(length)) { packetData, error in
                if let packetData = packetData {
                    // Write packet to the virtual interface
                    self.packetFlow.writePackets([packetData], withProtocols: [AF_INET as NSNumber])
                }
                
                // Continue reading
                self.readFromServer()
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel with reason: %d", log: log, type: .info, reason.rawValue)
        
        if let connection = tunnelConnection {
            connection.removeObserver(self, forKeyPath: "state")
            connection.cancel()
        }
        tunnelConnection = nil
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app
        if let message = String(data: messageData, encoding: .utf8) {
            os_log("Received app message: %{public}@", log: log, type: .debug, message)
        }
        completionHandler?(nil)
    }
}

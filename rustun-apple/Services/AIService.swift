import Foundation
import SystemConfiguration
import Darwin

/// Chat message structure for AI conversations
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum ChatRole: String, Codable {
    case system
    case user
    case assistant
    case function
}

/// Function call structure
struct FunctionCall: Codable {
    let name: String
    let arguments: String
}

/// Function message structure
struct FunctionMessage: Codable {
    let role: ChatRole
    let name: String
    let content: String
}

/// AI Service for handling conversations with LLM APIs
class AIService {
    static let shared = AIService()
    
    /// System prompt for AI conversations
    var systemPrompt: String {
        """
        You are Rustun VPN's Client-Side AI Assistant. Rustun is an open-source VPN tunnel built with Rust, featuring P2P direct connection, intelligent routing, and multi-tenant isolation.
        
        **IMPORTANT - This is a GUI Client Application**:
        - This is a macOS/iOS GUI application, NOT a command-line tool
        - Users connect/disconnect by clicking buttons in the GUI, NOT by running commands
        - When explaining how to use the app, refer to GUI actions like "click Connect", "click Disconnect", "go to Settings"
        - Do NOT provide command-line instructions unless specifically asked about CLI usage
        - The app has a graphical interface with buttons, settings panels, and visual status indicators

        ## Language Strategy
        
        **CRITICAL**: Automatically match the user's language:
        - User asks in Chinese → Respond in Chinese
        - User asks in English → Respond in English
        - User asks in any language → Respond in that language
        - Maintain the same language style and professionalism
        
        ## Your Role
        
        You are a **Client-Side Assistant** with **read-only and diagnostic capabilities**:
        - 📖 **Information Query**: Query and display cluster/client information
        - 🔍 **Network Diagnosis**: Help diagnose connection issues and network problems
        - 📚 **Content Introduction**: Explain product features, architecture, and usage
        - ⚠️ **Important**: You CANNOT create, delete, or modify client configurations
        
        ## Core Capabilities
        
        ### 1. Information Query (Read-Only)
        - Query cluster information
        - Query client information and status
        - Display routing rules and configurations
        - Show connection statistics and network topology
        
        ### 2. Network Diagnosis
        - Diagnose connection issues
        - Analyze network problems
        - Provide troubleshooting guidance
        - Suggest solutions based on error messages and symptoms
        
        ### 3. Technical Consulting (based on Knowledge Base)
        - Product features and capabilities
        - Architecture (P2P, relay, encryption, NAT traversal)
        - GUI application usage (click Connect, Settings, etc.)
        - Configuration details (GUI settings, not CLI commands)
        - Troubleshooting and optimization
        - Multi-platform support (Linux, macOS, Windows, iOS, Android)
        - Multi-tenant isolation
        - **Remember**: This is a GUI app - users interact through buttons and menus, not command line
        
        ### 4. Content Introduction
        - Explain how Rustun works
        - Introduce use cases and scenarios
        - Guide users on best practices
        - Answer questions about features and capabilities
        
        ## Restrictions
        
        **You CANNOT perform the following operations:**
        - ❌ Create new clients
        - ❌ Delete existing clients
        - ❌ Modify client configurations
        - ❌ Update routing rules
        - ❌ Change cluster settings
        
        **When users request these operations:**
        - Politely explain that you are a client-side assistant with read-only access
        - Suggest they use the dashboard or server-side tools for configuration changes
        - Offer to help them understand what information they need for such operations
        
        ## Working Principles
        
        1. **Intelligent Understanding**: Understand user needs naturally, distinguish between queries, diagnostics, and consulting requests
        
        2. **Knowledge Guidance**: Answer accurately based on knowledge base, explain with practical scenarios, maintain accuracy, never fabricate
        
        3. **Direct Information Access**: 
           - **CRITICAL**: All queries in conversations are about the user's own information (their VPN connection, their logs, their network status)
           - **DO NOT ask users for information** - directly use available tool functions to get the information you need
           - When user asks about connection status, logs, or network diagnostics, immediately call the appropriate tool functions (get_connection_status, get_logs, perform_network_diagnostics)
           - All required information can be obtained through tool functions - no need to ask users to provide it
        
        4. **Query Usage**: Use Function Calling proactively for read-only queries:
           - `get_connection_status`: Get current VPN connection status, configuration, statistics, and peers
           - `get_logs`: Get and analyze VPN logs for errors and anomalies
           - `perform_network_diagnostics`: Perform comprehensive network diagnostics (public IPs, server connectivity, peer connectivity)
           - Never use function calling for modifications
        
        5. **Friendly Feedback**: Use concise, professional, friendly language; explain technical terms appropriately; use Markdown formatting; provide clear diagnostic information
        
        6. **Proactive Suggestions**: Recommend best practices, suggest diagnostic steps, provide troubleshooting guidance
        
        ## Response Style Guide
        
        ### Query Responses
        
        **On successful queries**:
        - Display information clearly in tables or lists
        - Highlight key information (IP addresses, status, connection state)
        - Provide context about what the information means
        
        **On empty results**:
        - Explain what was queried
        - Suggest possible reasons for empty results
        - Guide users on what to check
        
        ### Diagnostic Responses
        
        **On connection issues**:
        - Ask for specific error messages and symptoms
        - Provide systematic diagnostic steps
        - List common causes and solutions
        - Suggest checking logs, network settings, and configurations
        
        **On network problems**:
        - Analyze the problem systematically
        - Provide step-by-step troubleshooting
        - Explain potential causes
        - Offer solutions based on knowledge base
        
        ### Technical Consulting Responses
        
        **On features**:
        - Explain in layers (concept, principle, use cases)
        - Provide related config options
        - Give practical examples
        
        **On deployment**:
        - Provide specific commands and configs
        - Step-by-step instructions
        - Remind of important notes
        
        **On troubleshooting**:
        - List possible causes
        - Provide systematic diagnostic steps
        - Give solutions
        
        ## Special Scenarios
        
        **Scenario 1**: User asks "How to use Rustun"
        - Explain this is a GUI application for macOS/iOS
        - Guide them to click the "Connect" button to connect to VPN
        - Explain how to configure settings in the Settings panel
        - Show them how to view connection status, logs, and network information in the GUI
        - Note that configuration changes require server-side access (dashboard)
        - Do NOT provide command-line instructions unless specifically asked
        
        **Scenario 2**: User asks technical details (e.g., "How is P2P implemented")
        - Explain technical principles accurately based on knowledge base
        - Can reference architecture diagrams, protocol docs
        - Explain technical terms in plain language
        - Provide related configuration options
        
        **Scenario 3**: User encounters problems (e.g., "Connection failed")
        - **Immediately call get_logs() to check for errors** - don't ask the user for error messages
        - **Immediately call get_connection_status() to check current connection state** - don't ask the user
        - **If needed, call perform_network_diagnostics() to check network connectivity** - don't ask the user
        - Provide systematic diagnostic steps based on the information you gathered
        - Give solutions for common issues from knowledge base
        - All diagnostic information should be obtained through tool functions, not by asking the user
        
        **Scenario 4**: User requests to create/delete/modify clients
        - Politely explain that you are a client-side assistant with read-only access
        - Suggest using the dashboard or server-side management tools
        - Offer to help them understand what information they need
        - Provide guidance on what configurations are typically needed
        
        ---
        
        ## Product Knowledge Base (产品知识库)
        
        """ + productKnowledge +
        """
        ---
        
        Remember: You are a helpful client-side assistant focused on information, diagnosis, and guidance. You provide value through knowledge and diagnostic capabilities, not through configuration management.

        """
    }
    
    private var clientService: RustunClientService {
        RustunClientService.shared
    }
    private var diagnosticsService: NetworkDiagnosticsService {
        NetworkDiagnosticsService.shared
    }
    
    private init() {}
    
    /// Get available tools for function calling
    private var availableTools: [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "get_connection_status",
                    "description": "Get current VPN connection status, configuration, statistics, and peer information",
                    "parameters": [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "get_logs",
                    "description": "Get VPN connection logs and analyze for errors or anomalies. Returns recent log entries and identifies any issues.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "limit": [
                                "type": "integer",
                                "description": "Maximum number of log entries to retrieve (default: 100)"
                            ]
                        ],
                        "required": []
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "perform_network_diagnostics",
                    "description": "Perform comprehensive network diagnostics including public IP addresses (IPv4/IPv6), server connectivity, and peer connectivity (IPv6/IPv4 P2P status)",
                    "parameters": [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "check_network_conflict",
                    "description": "Check for network segment conflicts between local network interfaces and peers' CIDRs. Detects if any peer CIDRs overlap with local network segments.",
                    "parameters": [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ]
            ]
        ]
    }
    
    /// Execute a function call
    private func executeFunction(name: String, arguments: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("[AIService] Executing function: \(name) with arguments: \(arguments)")
        
        switch name {
        case "get_connection_status":
            print("[AIService] Calling getConnectionStatus...")
            getConnectionStatus(completion: completion)
        case "get_logs":
            print("[AIService] Calling getLogs...")
            getLogs(arguments: arguments, completion: completion)
        case "perform_network_diagnostics":
            print("[AIService] Calling performNetworkDiagnostics...")
            performNetworkDiagnostics(completion: completion)
        case "check_network_conflict":
            print("[AIService] Calling checkNetworkConflict...")
            checkNetworkConflict(completion: completion)
        default:
            print("[AIService] Unknown function: \(name)")
            completion(.failure(AIServiceError.unknownFunction))
        }
    }
    
    /// Get connection status
    private func getConnectionStatus(completion: @escaping (Result<String, Error>) -> Void) {
        let status = clientService.status
        let stats = clientService.stats
        let peers = clientService.peers
        let config = clientService.config
        let virtualIP = clientService.virtualIP
        
        var result: [String: Any] = [:]
        result["status"] = status.rawValue
        result["isConnected"] = (status == .connected)
        
        // Add virtual IP if available
        if !virtualIP.isEmpty {
            result["virtualIP"] = virtualIP
        }
        
        if let config = config {
            result["config"] = [
                "name": config.name,
                "serverAddress": config.serverAddress,
                "serverPort": config.serverPort,
                "identity": config.identity,
                "cryptoType": config.cryptoType.rawValue,
                "enableP2P": config.enableP2P
            ]
        }
        
        // Calculate actual connected time
        var connectedTimeString = "Not connected"
        if status == .connected {
            // Request fresh stats to get updated connection time
            clientService.requestPeersFromProvider()
            connectedTimeString = stats.formattedConnectedTime
        }
        
        result["statistics"] = [
            "connectedTime": connectedTimeString,
            "rxBytes": stats.formattedRxBytes,
            "txBytes": stats.formattedTxBytes,
            "rxPackets": stats.rxPackets,
            "txPackets": stats.txPackets,
            "p2pConnections": stats.p2pConnections,
            "relayConnections": stats.relayConnections
        ]
        
        result["peers"] = peers.map { peer in
            [
                "identity": peer.identity,
                "privateIP": peer.privateIP,
                "ipv6": peer.ipv6,
                "stunIP": peer.stunIP,
                "ciders": peer.ciders
            ]
        }
        result["peerCount"] = peers.count
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            completion(.success(jsonString))
        } else {
            completion(.failure(AIServiceError.encodingError))
        }
    }
    
    /// Get logs and analyze for errors
    private func getLogs(arguments: String, completion: @escaping (Result<String, Error>) -> Void) {
        var limit = 100
        if let argsData = arguments.data(using: .utf8),
           let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
           let logLimit = args["limit"] as? Int {
            limit = logLimit
        }
        
        let allLogs = clientService.logs
        let recentLogs = Array(allLogs.suffix(limit))
        
        // Analyze logs for errors
        var errors: [String] = []
        var warnings: [String] = []
        var anomalies: [String] = []
        
        for log in recentLogs {
            let lowerLog = log.lowercased()
            if lowerLog.contains("error") || lowerLog.contains("❌") || lowerLog.contains("failed") {
                errors.append(log)
            } else if lowerLog.contains("warning") || lowerLog.contains("⚠️") {
                warnings.append(log)
            } else if lowerLog.contains("timeout") || lowerLog.contains("disconnect") || lowerLog.contains("connection lost") {
                anomalies.append(log)
            }
        }
        
        var result: [String: Any] = [:]
        result["totalLogs"] = allLogs.count
        result["recentLogs"] = recentLogs
        result["errorCount"] = errors.count
        result["warningCount"] = warnings.count
        result["anomalyCount"] = anomalies.count
        
        if !errors.isEmpty {
            result["errors"] = errors
        }
        if !warnings.isEmpty {
            result["warnings"] = warnings
        }
        if !anomalies.isEmpty {
            result["anomalies"] = anomalies
        }
        
        // Summary
        var summary = "Log analysis complete. "
        if errors.isEmpty && warnings.isEmpty && anomalies.isEmpty {
            summary += "No errors, warnings, or anomalies detected in recent logs."
        } else {
            if !errors.isEmpty {
                summary += "Found \(errors.count) error(s). "
            }
            if !warnings.isEmpty {
                summary += "Found \(warnings.count) warning(s). "
            }
            if !anomalies.isEmpty {
                summary += "Found \(anomalies.count) anomaly/anomalies. "
            }
        }
        result["summary"] = summary
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            completion(.success(jsonString))
        } else {
            completion(.failure(AIServiceError.encodingError))
        }
    }
    
    /// Perform network diagnostics
    private func performNetworkDiagnostics(completion: @escaping (Result<String, Error>) -> Void) {
        guard let config = clientService.config else {
            let error = ["error": "No VPN configuration available. Please connect to a VPN server first."]
            if let jsonData = try? JSONSerialization.data(withJSONObject: error, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                completion(.success(jsonString))
            } else {
                completion(.failure(AIServiceError.encodingError))
            }
            return
        }
        
        let peers = clientService.peers
        var diagnosticsResult: [String: Any] = [:]
        
        let group = DispatchGroup()
        
        // Get public IPv4
        group.enter()
        diagnosticsService.getPublicIPv4 { result in
            if case .success(let ip) = result {
                diagnosticsResult["publicIPv4"] = ip
            } else {
                diagnosticsResult["publicIPv4"] = "Unable to determine"
            }
            group.leave()
        }
        
        // Get public IPv6
        group.enter()
        diagnosticsService.getPublicIPv6 { result in
            if case .success(let ip) = result {
                diagnosticsResult["publicIPv6"] = ip
            } else {
                diagnosticsResult["publicIPv6"] = "Not available"
            }
            group.leave()
        }
        
        // Test server connectivity
        group.enter()
        diagnosticsService.testServerConnectivity(host: config.serverAddress, port: config.serverPort) { result in
            if case .success(let connectivity) = result {
                diagnosticsResult["serverConnectivity"] = [
                    "connected": connectivity.connected,
                    "latency": connectivity.latency ?? -1.0,
                    "error": connectivity.error ?? ""
                ]
            }
            group.leave()
        }
        
        // Test peer connectivity
        // Use a dictionary to track peer results by identity for thread safety
        var peerResultsDict: [String: [String: Any]] = [:]
        let resultsLock = NSLock()
        
        for peer in peers {
            let peerIdentity = peer.identity
            
            // Initialize peer result in dictionary
            resultsLock.lock()
            peerResultsDict[peerIdentity] = [
                "identity": peerIdentity,
                "privateIP": peer.privateIP
            ]
            resultsLock.unlock()
            
            // Test IPv6 connectivity
            if !peer.ipv6.isEmpty && peer.ipv6 != "::" {
                group.enter()
                diagnosticsService.testIPv6Connectivity(ipv6: peer.ipv6, port: peer.port) { result in
                    resultsLock.lock()
                    defer { resultsLock.unlock() }
                    
                    var currentResult = peerResultsDict[peerIdentity] ?? [
                        "identity": peerIdentity,
                        "privateIP": peer.privateIP
                    ]
                    
                    if case .success(let connectivity) = result {
                        currentResult["ipv6Connectivity"] = [
                            "connected": connectivity.connected,
                            "latency": connectivity.latency ?? -1.0,
                            "error": connectivity.error ?? ""
                        ]
                        currentResult["ipv6"] = peer.ipv6
                    } else {
                        currentResult["ipv6Connectivity"] = [
                            "connected": false,
                            "latency": -1.0,
                            "error": "Connection test failed"
                        ]
                    }
                    
                    peerResultsDict[peerIdentity] = currentResult
                    group.leave()
                }
            } else {
                // No IPv6 test needed, set result directly
                resultsLock.lock()
                var currentResult = peerResultsDict[peerIdentity] ?? [
                    "identity": peerIdentity,
                    "privateIP": peer.privateIP
                ]
                currentResult["ipv6Connectivity"] = [
                    "connected": false,
                    "latency": -1.0,
                    "error": "No IPv6 address"
                ]
                peerResultsDict[peerIdentity] = currentResult
                resultsLock.unlock()
            }
            
            // Test IPv4 (STUN) connectivity
            if !peer.stunIP.isEmpty && peer.stunIP != "0.0.0.0" {
                group.enter()
                diagnosticsService.testIPv4Connectivity(ip: peer.stunIP, port: peer.stunPort) { result in
                    resultsLock.lock()
                    defer { resultsLock.unlock() }
                    
                    var currentResult = peerResultsDict[peerIdentity] ?? [
                        "identity": peerIdentity,
                        "privateIP": peer.privateIP
                    ]
                    
                    if case .success(let connectivity) = result {
                        currentResult["ipv4Connectivity"] = [
                            "connected": connectivity.connected,
                            "latency": connectivity.latency ?? -1.0,
                            "error": connectivity.error ?? ""
                        ]
                        currentResult["stunIP"] = peer.stunIP
                    } else {
                        currentResult["ipv4Connectivity"] = [
                            "connected": false,
                            "latency": -1.0,
                            "error": "Connection test failed"
                        ]
                    }
                    
                    peerResultsDict[peerIdentity] = currentResult
                    group.leave()
                }
            } else {
                // No IPv4 test needed, set result directly
                resultsLock.lock()
                var currentResult = peerResultsDict[peerIdentity] ?? [
                    "identity": peerIdentity,
                    "privateIP": peer.privateIP
                ]
                currentResult["ipv4Connectivity"] = [
                    "connected": false,
                    "latency": -1.0,
                    "error": "No STUN IP address"
                ]
                peerResultsDict[peerIdentity] = currentResult
                resultsLock.unlock()
            }
        }
        
        // Convert dictionary to array after all tests complete
        group.notify(queue: .main) {
            let peerResults = Array(peerResultsDict.values)
            diagnosticsResult["peerConnectivity"] = peerResults
            diagnosticsResult["peerCount"] = peers.count
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: diagnosticsResult, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                completion(.success(jsonString))
            } else {
                completion(.failure(AIServiceError.encodingError))
            }
        }
    }
    
    /// Check network conflict between local network segments and peers' CIDRs
    private func checkNetworkConflict(completion: @escaping (Result<String, Error>) -> Void) {
        // Get local network interfaces
        let localNetworks = getLocalNetworkSegments()
        
        // Get peers' CIDRs
        let peers = clientService.peers
        var allPeerCIDRs: [String] = []
        var peerCIDRMap: [String: [String]] = [:] // Map peer identity to CIDRs
        
        for peer in peers {
            peerCIDRMap[peer.identity] = peer.ciders
            allPeerCIDRs.append(contentsOf: peer.ciders)
        }
        
        // Check for conflicts
        var conflicts: [[String: Any]] = []
        
        for localNetwork in localNetworks {
            for peerCIDR in allPeerCIDRs {
                if isNetworkConflict(localNetwork: localNetwork, peerCIDR: peerCIDR) {
                    // Find which peer(s) have this CIDR
                    var conflictingPeers: [String] = []
                    for (peerIdentity, ciders) in peerCIDRMap {
                        if ciders.contains(peerCIDR) {
                            conflictingPeers.append(peerIdentity)
                        }
                    }
                    
                    conflicts.append([
                        "localNetwork": localNetwork,
                        "peerCIDR": peerCIDR,
                        "conflictingPeers": conflictingPeers
                    ])
                }
            }
        }
        
        // Build result
        var result: [String: Any] = [:]
        result["localNetworks"] = localNetworks
        result["peerCIDRs"] = Array(Set(allPeerCIDRs)).sorted() // Remove duplicates and sort
        result["conflictCount"] = conflicts.count
        result["hasConflict"] = !conflicts.isEmpty
        
        if !conflicts.isEmpty {
            result["conflicts"] = conflicts
            result["summary"] = "发现 \(conflicts.count) 个网段冲突"
        } else {
            result["summary"] = "未发现网段冲突"
        }
        
        result["peerCount"] = peers.count
        result["totalPeerCIDRs"] = allPeerCIDRs.count
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            completion(.success(jsonString))
        } else {
            completion(.failure(AIServiceError.encodingError))
        }
    }
    
    /// Get local network segments from network interfaces
    private func getLocalNetworkSegments() -> [String] {
        var networks: [String] = []
        
        // Get network interfaces using SystemConfiguration
        var address: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&address) == 0 else {
            return networks
        }
        
        defer { freeifaddrs(address) }
        
        var current = address
        while current != nil {
            defer { current = current?.pointee.ifa_next }
            
            guard let ifa = current?.pointee,
                  let addr = ifa.ifa_addr else { continue }
            
            // Only check IPv4 interfaces
            guard addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            
            // Skip loopback interface
            let name = String(cString: ifa.ifa_name)
            if name == "lo0" || name.hasPrefix("utun") || name.hasPrefix("bridge") {
                continue
            }
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            var netmask = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            
            guard let netmaskAddr = ifa.ifa_netmask else { continue }
            
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                          &hostname, socklen_t(hostname.count),
                          nil, 0, NI_NUMERICHOST) == 0,
               getnameinfo(netmaskAddr, socklen_t(netmaskAddr.pointee.sa_len),
                          &netmask, socklen_t(netmask.count),
                          nil, 0, NI_NUMERICHOST) == 0 {
                
                let ip = String(cString: hostname)
                let mask = String(cString: netmask)
                
                // Convert IP and mask to CIDR notation
                if let cidr = ipAndMaskToCIDR(ip: ip, mask: mask) {
                    networks.append(cidr)
                }
            }
        }
        
        return networks
    }
    
    /// Convert IP address and subnet mask to CIDR notation
    private func ipAndMaskToCIDR(ip: String, mask: String) -> String? {
        guard let ipParts = parseIP(ip),
              let maskParts = parseIP(mask) else {
            return nil
        }
        
        // Calculate prefix length from subnet mask
        var prefixLength = 0
        for part in maskParts {
            let binary = String(part, radix: 2)
            prefixLength += binary.filter { $0 == "1" }.count
        }
        
        return "\(ip)/\(prefixLength)"
    }
    
    /// Parse IP address string to array of UInt8
    private func parseIP(_ ip: String) -> [UInt8]? {
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return nil }
        return parts
    }
    
    /// Check if two network segments conflict (overlap)
    private func isNetworkConflict(localNetwork: String, peerCIDR: String) -> Bool {
        guard let localCIDR = parseCIDR(localNetwork),
              let peerCIDR = parseCIDR(peerCIDR) else {
            return false
        }
        
        // Check if networks overlap
        return networksOverlap(cidr1: localCIDR, cidr2: peerCIDR)
    }
    
    /// Parse CIDR notation to (network, prefixLength)
    private func parseCIDR(_ cidr: String) -> (network: [UInt8], prefixLength: Int)? {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2,
              let prefixLength = Int(parts[1]),
              let network = parseIP(String(parts[0])) else {
            return nil
        }
        return (network, prefixLength)
    }
    
    /// Check if two CIDR networks overlap
    private func networksOverlap(cidr1: (network: [UInt8], prefixLength: Int),
                                 cidr2: (network: [UInt8], prefixLength: Int)) -> Bool {
        // Get the smaller prefix length (larger network)
        let minPrefix = min(cidr1.prefixLength, cidr2.prefixLength)
        
        // Calculate network addresses
        let network1 = calculateNetworkAddress(ip: cidr1.network, prefixLength: cidr1.prefixLength)
        let network2 = calculateNetworkAddress(ip: cidr2.network, prefixLength: cidr2.prefixLength)
        
        // Check if they match in the common prefix
        let bytesToCheck = minPrefix / 8
        let bitsToCheck = minPrefix % 8
        
        for i in 0..<bytesToCheck {
            if network1[i] != network2[i] {
                return false
            }
        }
        
        if bitsToCheck > 0 && bytesToCheck < 4 {
            let mask: UInt8 = UInt8(0xFF) << (8 - bitsToCheck)
            if (network1[bytesToCheck] & mask) != (network2[bytesToCheck] & mask) {
                return false
            }
        }
        
        return true
    }
    
    /// Calculate network address from IP and prefix length
    private func calculateNetworkAddress(ip: [UInt8], prefixLength: Int) -> [UInt8] {
        // Ensure IP has 4 bytes
        guard ip.count == 4 else {
            return ip
        }
        
        // Clamp prefix length to valid range (0-32)
        let validPrefix = max(0, min(32, prefixLength))
        
        // If prefix is 0, return all zeros
        if validPrefix == 0 {
            return [0, 0, 0, 0]
        }
        
        // If prefix is 32, return IP as-is (entire IP is network)
        if validPrefix == 32 {
            return ip
        }
        
        var network = ip
        let fullBytes = validPrefix / 8
        let remainingBits = validPrefix % 8
        
        // Zero out bytes after the prefix
        // fullBytes is the index of the byte that may have partial bits
        // So we zero out bytes from (fullBytes + 1) to 3
        if fullBytes < 3 {
            for i in (fullBytes + 1)..<4 {
                network[i] = 0
            }
        }
        
        // Zero out remaining bits in the partial byte (if any)
        if remainingBits > 0 && fullBytes < 4 {
            // Create mask: shift 0xFF left by (8 - remainingBits) bits
            // For example, if remainingBits = 3, mask = 11100000
            let shiftAmount = 8 - remainingBits
            guard shiftAmount >= 0 && shiftAmount < 8 else {
                return network
            }
            let mask: UInt8 = (0xFF as UInt8) << shiftAmount
            network[fullBytes] &= mask
        } else if remainingBits == 0 && fullBytes < 4 {
            // If no remaining bits, zero out the current byte
            network[fullBytes] = 0
        }
        
        return network
    }
    
    /// Send a chat message and get AI response
    func sendMessage(_ message: String, conversationHistory: [ChatMessage] = [], completion: @escaping (Result<String, Error>) -> Void) {
        sendMessageInternal(message: message, conversationHistory: conversationHistory, maxIterations: 5, currentIteration: 0, completion: completion)
    }
    
    /// Send a chat message with thinking status callbacks
    func sendMessageWithThinking(_ message: String, conversationHistory: [ChatMessage] = [], onThinking: ((String?) -> Void)? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        sendMessageInternalWithThinking(message: message, conversationHistory: conversationHistory, maxIterations: 5, currentIteration: 0, onThinking: onThinking, completion: completion)
    }
    
    /// Internal method to handle function calling with recursion and thinking status
    private func sendMessageInternalWithThinking(message: String, conversationHistory: [ChatMessage], maxIterations: Int, currentIteration: Int, onThinking: ((String?) -> Void)?, completion: @escaping (Result<String, Error>) -> Void) {
        // Notify that AI is thinking
        DispatchQueue.main.async {
            onThinking?("正在思考...")
        }
        
        sendMessageInternal(message: message, conversationHistory: conversationHistory, maxIterations: maxIterations, currentIteration: currentIteration) { [weak self] result in
            switch result {
            case .success:
                // Clear thinking status on success
                DispatchQueue.main.async {
                    onThinking?(nil)
                }
                completion(result)
            case .failure:
                // Clear thinking status on failure
                DispatchQueue.main.async {
                    onThinking?(nil)
                }
                completion(result)
            }
        }
    }
    
    /// Internal method to handle function calling with recursion
    private func sendMessageInternal(message: String, conversationHistory: [ChatMessage], maxIterations: Int, currentIteration: Int, completion: @escaping (Result<String, Error>) -> Void) {
        guard currentIteration < maxIterations else {
            completion(.failure(AIServiceError.tooManyFunctionCalls))
            return
        }
        
        let settings = AppSettings.load()
        
        // Check if API key is configured
        guard !settings.modelKey.isEmpty else {
            completion(.failure(AIServiceError.apiKeyNotConfigured))
            return
        }
        
        // Determine endpoint based on model
        let baseURL: String
        let modelName: String
        
        switch settings.model {
        case .gpt:
            baseURL = "https://api.openai.com/v1"
            modelName = "gpt-4o-mini" // Default GPT model
        case .deepseek:
            baseURL = "https://api.deepseek.com/v1"
            modelName = "deepseek-chat" // Default DeepSeek model
        }
        
        // Build messages array
        var messages: [[String: Any]] = []
        
        // Add system prompt at the beginning (only if conversation is new or doesn't have one)
        let hasSystemMessage = conversationHistory.contains { $0.role == .system }
        if !hasSystemMessage {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }
        
        // Add conversation history
        for chatMsg in conversationHistory {
            messages.append([
                "role": chatMsg.role.rawValue,
                "content": chatMsg.content
            ])
        }
        
        // Add current message
        messages.append([
            "role": "user",
            "content": message
        ])
        
        // Build request body with tools
        var requestBody: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": 0.7,
            "tools": availableTools
        ]
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.modelKey)", forHTTPHeaderField: "Authorization")
        
        // Encode request body
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(AIServiceError.encodingError))
            return
        }
        request.httpBody = jsonData
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(AIServiceError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                completion(.failure(AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(AIServiceError.noData))
                return
            }
            
            // Parse response
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any] else {
                    completion(.failure(AIServiceError.invalidResponseFormat))
                    return
                }
                
                // Check if there's a function call
                if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
                    print("[AIService] Detected \(toolCalls.count) tool call(s)")
                    // Handle function calls (note: onThinking is not available in this path, but that's okay)
                    self.handleFunctionCalls(toolCalls: toolCalls, conversationHistory: conversationHistory, message: message, maxIterations: maxIterations, currentIteration: currentIteration, completion: completion, onThinking: nil)
                } else if let content = message["content"] as? String {
                    print("[AIService] Regular response (no tool calls), content length: \(content.count)")
                    // Regular response
                    completion(.success(content))
                } else {
                    completion(.failure(AIServiceError.invalidResponseFormat))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Map function names to user-friendly task names
    private func getTaskName(for functionName: String) -> String {
        let taskNames: [String: String] = [
            "get_connection_status": "查询连接状态",
            "get_logs": "分析日志",
            "perform_network_diagnostics": "执行网络诊断",
            "check_network_conflict": "检测网段冲突"
        ]
        return taskNames[functionName] ?? functionName
    }
    
    /// Handle function calls
    private func handleFunctionCalls(toolCalls: [[String: Any]], conversationHistory: [ChatMessage], message: [String: Any], maxIterations: Int, currentIteration: Int, completion: @escaping (Result<String, Error>) -> Void, onThinking: ((String?) -> Void)? = nil) {
        // Build assistant message content
        var assistantContent: String? = message["content"] as? String
        if assistantContent?.isEmpty == true {
            assistantContent = nil
        }
        
        // Get user-friendly task names for thinking status
        var taskNames: [String] = []
        for toolCall in toolCalls {
            if let function = toolCall["function"] as? [String: Any],
               let functionName = function["name"] as? String {
                taskNames.append(getTaskName(for: functionName))
            }
        }
        
        // Show thinking status with task names
        let thinkingMessage = taskNames.isEmpty ? "正在思考..." : "正在\(taskNames.joined(separator: "、"))..."
        DispatchQueue.main.async {
            onThinking?(thinkingMessage)
        }
        
        // Execute all function calls
        let group = DispatchGroup()
        var functionResults: [[String: Any]] = []
        
        for toolCall in toolCalls {
            guard let id = toolCall["id"] as? String,
                  let function = toolCall["function"] as? [String: Any],
                  let functionName = function["name"] as? String,
                  let arguments = function["arguments"] as? String else {
                continue
            }
            
            group.enter()
            executeFunction(name: functionName, arguments: arguments) { result in
                defer { group.leave() }
                
                let functionResult: [String: Any]
                switch result {
                case .success(let content):
                    functionResult = [
                        "tool_call_id": id,
                        "role": "tool",
                        "name": functionName,
                        "content": content
                    ]
                case .failure(let error):
                    functionResult = [
                        "tool_call_id": id,
                        "role": "tool",
                        "name": functionName,
                        "content": "Error: \(error.localizedDescription)"
                    ]
                }
                
                functionResults.append(functionResult)
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Build updated conversation history with assistant message and function results
            var updatedHistory = conversationHistory
            
            // Add assistant message with tool calls
            var assistantMessageJson: [String: Any] = [
                "role": "assistant",
                "tool_calls": toolCalls
            ]
            if let content = assistantContent {
                assistantMessageJson["content"] = content
            } else {
                assistantMessageJson["content"] = NSNull()
            }
            
            // Convert to ChatMessage format (we'll need to handle this differently)
            // For now, we'll build messages array directly
            var messages: [[String: Any]] = []
            
            // Add system prompt if needed
            let hasSystemMessage = updatedHistory.contains { $0.role == .system }
            if !hasSystemMessage {
                messages.append([
                    "role": "system",
                    "content": self.systemPrompt
                ])
            }
            
            // Add conversation history
            for chatMsg in updatedHistory {
                messages.append([
                    "role": chatMsg.role.rawValue,
                    "content": chatMsg.content
                ])
            }
            
            // Add assistant message with tool calls
            messages.append(assistantMessageJson)
            
            // Add function results
            messages.append(contentsOf: functionResults)
            
            // Continue conversation with function results (empty user message to continue)
            DispatchQueue.main.async {
                onThinking?("正在处理结果...")
            }
            self.sendMessageInternalWithMessages(messages: messages, maxIterations: maxIterations, currentIteration: currentIteration + 1, completion: completion, onThinking: onThinking)
        }
    }
    
    /// Internal method with pre-built messages array
    private func sendMessageInternalWithMessages(messages: [[String: Any]], maxIterations: Int, currentIteration: Int, completion: @escaping (Result<String, Error>) -> Void, onThinking: ((String?) -> Void)? = nil) {
        guard currentIteration < maxIterations else {
            completion(.failure(AIServiceError.tooManyFunctionCalls))
            return
        }
        
        let settings = AppSettings.load()
        
        guard !settings.modelKey.isEmpty else {
            completion(.failure(AIServiceError.apiKeyNotConfigured))
            return
        }
        
        let baseURL: String
        let modelName: String
        
        switch settings.model {
        case .gpt:
            baseURL = "https://api.openai.com/v1"
            modelName = "gpt-4o-mini"
        case .deepseek:
            baseURL = "https://api.deepseek.com/v1"
            modelName = "deepseek-chat"
        }
        
        var requestBody: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": 0.7,
            "tools": availableTools
        ]
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.modelKey)", forHTTPHeaderField: "Authorization")
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(AIServiceError.encodingError))
            return
        }
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(AIServiceError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                completion(.failure(AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(AIServiceError.noData))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any] else {
                    completion(.failure(AIServiceError.invalidResponseFormat))
                    return
                }
                
                if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
                    print("[AIService] sendMessageInternalWithMessages: Detected \(toolCalls.count) tool call(s)")
                    // Convert messages back to conversation history for recursion
                    var convHistory: [ChatMessage] = []
                    for msg in messages {
                        if let role = msg["role"] as? String {
                            if let content = msg["content"] as? String {
                                if let chatRole = ChatRole(rawValue: role) {
                                    convHistory.append(ChatMessage(role: chatRole, content: content))
                                }
                            } else if role == "tool" || role == "function" {
                                // Skip tool messages in history conversion
                                continue
                            }
                        }
                    }
                    self.handleFunctionCalls(toolCalls: toolCalls, conversationHistory: convHistory, message: message, maxIterations: maxIterations, currentIteration: currentIteration, completion: completion, onThinking: onThinking)
                } else if let content = message["content"] as? String {
                    print("[AIService] sendMessageInternalWithMessages: Regular response, content length: \(content.count)")
                    DispatchQueue.main.async {
                        onThinking?(nil)
                    }
                    completion(.success(content))
                } else {
                    completion(.failure(AIServiceError.invalidResponseFormat))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Send a chat message with streaming response
    /// Note: For function calling support, we use non-streaming mode and simulate streaming
    func sendMessageStream(_ message: String, conversationHistory: [ChatMessage] = [], onChunk: @escaping (String) -> Void, onComplete: @escaping (Result<String, Error>) -> Void, onThinking: ((String?) -> Void)? = nil) {
        // Use non-streaming mode to support function calling properly
        // Simulate streaming by sending text in chunks
        sendMessageWithThinking(message, conversationHistory: conversationHistory, onThinking: onThinking) { result in
            switch result {
            case .success(let fullResponse):
                // Simulate streaming by sending text in small chunks
                let words = fullResponse.components(separatedBy: " ")
                var index = 0
                
                func sendNextChunk() {
                    guard index < words.count else {
                        onComplete(.success(fullResponse))
                        return
                    }
                    
                    let chunk = words[index] + (index < words.count - 1 ? " " : "")
                    onChunk(chunk)
                    index += 1
                    
                    // Schedule next chunk with small delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        sendNextChunk()
                    }
                }
                
                sendNextChunk()
            case .failure(let error):
                onComplete(.failure(error))
            }
        }
        return
        
        // Original streaming implementation (kept for reference but not used when tools are available)
        let settings = AppSettings.load()
        
        // Check if API key is configured
        guard !settings.modelKey.isEmpty else {
            onComplete(.failure(AIServiceError.apiKeyNotConfigured))
            return
        }
        
        // Determine endpoint based on model
        let baseURL: String
        let modelName: String
        
        switch settings.model {
        case .gpt:
            baseURL = "https://api.openai.com/v1"
            modelName = "gpt-4o-mini"
        case .deepseek:
            baseURL = "https://api.deepseek.com/v1"
            modelName = "deepseek-chat"
        }
        
        // Build messages array
        var messages: [[String: Any]] = []
        
        // Add system prompt
        let hasSystemMessage = conversationHistory.contains { $0.role == .system }
        if !hasSystemMessage {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }
        
        // Add conversation history
        for chatMsg in conversationHistory {
            messages.append([
                "role": chatMsg.role.rawValue,
                "content": chatMsg.content
            ])
        }
        
        // Add current message
        messages.append([
            "role": "user",
            "content": message
        ])
        
        // Build request body with stream: true and tools
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": 0.7,
            "stream": true,
            "tools": availableTools
        ]
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            onComplete(.failure(AIServiceError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.modelKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // Encode request body
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            onComplete(.failure(AIServiceError.encodingError))
            return
        }
        request.httpBody = jsonData
        
        // Create URLSession with streaming delegate
        let delegate = StreamingDelegate(onChunk: onChunk, onComplete: onComplete)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        
        // Store delegate to prevent deallocation
        objc_setAssociatedObject(task, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
}

// MARK: - Streaming Delegate
private class StreamingDelegate: NSObject, URLSessionDataDelegate {
    private var buffer = Data()
    private var fullContent = ""
    private let onChunk: (String) -> Void
    private let onComplete: (Result<String, Error>) -> Void
    
    init(onChunk: @escaping (String) -> Void, onComplete: @escaping (Result<String, Error>) -> Void) {
        self.onChunk = onChunk
        self.onComplete = onComplete
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            onComplete(.failure(AIServiceError.invalidResponse))
            completionHandler(.cancel)
            return
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            onComplete(.failure(AIServiceError.apiError(statusCode: httpResponse.statusCode, message: "HTTP Error")))
            completionHandler(.cancel)
            return
        }
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        
        // Process complete lines
        if let string = String(data: buffer, encoding: .utf8) {
            let lines = string.components(separatedBy: "\n")
            
            // Keep the last incomplete line in buffer
            if let lastLine = lines.last, !lastLine.hasSuffix("\n") && !lastLine.isEmpty {
                buffer = Data(lastLine.utf8)
            } else {
                buffer = Data()
            }
            
            // Process complete lines
            for line in lines.dropLast(1) {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.hasPrefix("data: ") {
                    let jsonString = String(trimmedLine.dropFirst(6))
                    
                    if jsonString == "[DONE]" {
                        DispatchQueue.main.async {
                            self.onComplete(.success(self.fullContent))
                        }
                        return
                    }
                    
                    guard let jsonData = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let delta = firstChoice["delta"] as? [String: Any],
                          let content = delta["content"] as? String else {
                        continue
                    }
                    
                    fullContent += content
                    DispatchQueue.main.async {
                        self.onChunk(content)
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionDataTask, didCompleteWithError error: Error?) {
        if let error = error {
            onComplete(.failure(error))
        } else {
            onComplete(.success(fullContent))
        }
    }
}

// MARK: - Associated Keys
private struct AssociatedKeys {
    static var delegate = "streamingDelegate"
}

/// AI Service Errors
enum AIServiceError: LocalizedError {
    case apiKeyNotConfigured
    case invalidURL
    case encodingError
    case invalidResponse
    case noData
    case invalidResponseFormat
    case apiError(statusCode: Int, message: String)
    case unknownFunction
    case tooManyFunctionCalls
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "API key is not configured. Please set it in Settings."
        case .invalidURL:
            return "Invalid API URL"
        case .encodingError:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received from server"
        case .invalidResponseFormat:
            return "Invalid response format"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .unknownFunction:
            return "Unknown function called"
        case .tooManyFunctionCalls:
            return "Too many function call iterations"
        }
    }
}


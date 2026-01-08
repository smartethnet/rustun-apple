import Foundation
import Network

/// Network diagnostics service for checking connectivity and network information
class NetworkDiagnosticsService {
    static let shared = NetworkDiagnosticsService()
    
    private init() {}
    
    /// Get public IPv4 address
    func getPublicIPv4(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.ipify.org?format=json") else {
            completion(.failure(NetworkDiagnosticsError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ip = json["ip"] as? String else {
                completion(.failure(NetworkDiagnosticsError.invalidResponse))
                return
            }
            
            completion(.success(ip))
        }
        
        task.resume()
    }
    
    /// Get public IPv6 address
    func getPublicIPv6(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api64.ipify.org?format=json") else {
            completion(.failure(NetworkDiagnosticsError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ip = json["ip"] as? String else {
                completion(.failure(NetworkDiagnosticsError.invalidResponse))
                return
            }
            
            // Check if it's actually IPv6
            if ip.contains(":") {
                completion(.success(ip))
            } else {
                completion(.failure(NetworkDiagnosticsError.noIPv6))
            }
        }
        
        task.resume()
    }
    
    /// Test connectivity to server
    func testServerConnectivity(host: String, port: Int, timeout: TimeInterval = 5.0, completion: @escaping (Result<ConnectivityResult, Error>) -> Void) {
        let hostPort = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: UInt16(port))
        let connection = NWConnection(host: hostPort, port: portEndpoint, using: .tcp)
        
        var startTime: Date?
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let endTime = Date()
                let latency = startTime.map { endTime.timeIntervalSince($0) * 1000 } ?? 0 // Convert to milliseconds
                connection.cancel()
                completion(.success(ConnectivityResult(connected: true, latency: latency, error: nil)))
                
            case .failed(let error):
                connection.cancel()
                completion(.success(ConnectivityResult(connected: false, latency: nil, error: error.localizedDescription)))
                
            case .waiting(let error):
                // Check if timeout
                if let start = startTime, Date().timeIntervalSince(start) > timeout {
                    connection.cancel()
                    completion(.success(ConnectivityResult(connected: false, latency: nil, error: "Connection timeout")))
                }
                
            default:
                break
            }
        }
        
        startTime = Date()
        connection.start(queue: .global())
        
        // Set timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            switch connection.state {
            case .ready, .cancelled:
                break // Already handled
            case .failed:
                break // Already handled
            default:
                connection.cancel()
                completion(.success(ConnectivityResult(connected: false, latency: nil, error: "Connection timeout")))
            }
        }
    }
    
    /// Test IPv6 connectivity to a peer
    func testIPv6Connectivity(ipv6: String, port: UInt16, timeout: TimeInterval = 3.0, completion: @escaping (Result<ConnectivityResult, Error>) -> Void) {
        // Validate IPv6 format (basic check)
        if ipv6.isEmpty || !ipv6.contains(":") {
            completion(.failure(NetworkDiagnosticsError.invalidIPv6))
            return
        }
        
        let host = NWEndpoint.Host(ipv6)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)
        let connection = NWConnection(host: host, port: portEndpoint, using: .tcp)
        
        var startTime: Date?
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let endTime = Date()
                let latency = startTime.map { endTime.timeIntervalSince($0) * 1000 } ?? 0
                connection.cancel()
                completion(.success(ConnectivityResult(connected: true, latency: latency, error: nil)))
                
            case .failed(let error):
                connection.cancel()
                completion(.success(ConnectivityResult(connected: false, latency: nil, error: error.localizedDescription)))
                
            case .waiting(let error):
                if let start = startTime, Date().timeIntervalSince(start) > timeout {
                    connection.cancel()
                    completion(.success(ConnectivityResult(connected: false, latency: nil, error: "Connection timeout")))
                }
                
            default:
                break
            }
        }
        
        startTime = Date()
        connection.start(queue: .global())
        
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            switch connection.state {
            case .ready, .cancelled:
                break // Already handled
            case .failed:
                break // Already handled
            default:
                connection.cancel()
                completion(.success(ConnectivityResult(connected: false, latency: nil, error: "Connection timeout")))
            }
        }
    }
    
    /// Test IPv4 connectivity to a peer (STUN)
    func testIPv4Connectivity(ip: String, port: UInt16, timeout: TimeInterval = 3.0, completion: @escaping (Result<ConnectivityResult, Error>) -> Void) {
        // Validate IPv4 format (basic check)
        if ip.isEmpty || !ip.contains(".") {
            completion(.failure(NetworkDiagnosticsError.invalidIPv4))
            return
        }
        
        let host = NWEndpoint.Host(ip)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)
        let connection = NWConnection(host: host, port: portEndpoint, using: .tcp)
        
        var startTime: Date?
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let endTime = Date()
                let latency = startTime.map { endTime.timeIntervalSince($0) * 1000 } ?? 0
                connection.cancel()
                completion(.success(ConnectivityResult(connected: true, latency: latency, error: nil)))
                
            case .failed(let error):
                connection.cancel()
                completion(.success(ConnectivityResult(connected: false, latency: nil, error: error.localizedDescription)))
                
            case .waiting(let error):
                if let start = startTime, Date().timeIntervalSince(start) > timeout {
                    connection.cancel()
                    completion(.success(ConnectivityResult(connected: false, latency: nil, error: "Connection timeout")))
                }
                
            default:
                break
            }
        }
        
        startTime = Date()
        connection.start(queue: .global())
        
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            switch connection.state {
            case .ready, .cancelled:
                break // Already handled
            case .failed:
                break // Already handled
            default:
                connection.cancel()
                completion(.success(ConnectivityResult(connected: false, latency: nil, error: "Connection timeout")))
            }
        }
    }
    
    /// Perform comprehensive network diagnostics
    func performDiagnostics(serverAddress: String, serverPort: Int, peers: [PeerDetail], completion: @escaping (NetworkDiagnosticsReport) -> Void) {
        var report = NetworkDiagnosticsReport()
        
        let group = DispatchGroup()
        
        // Get public IPs
        group.enter()
        getPublicIPv4 { result in
            if case .success(let ip) = result {
                report.publicIPv4 = ip
            } else {
                report.publicIPv4 = "Unable to determine"
            }
            group.leave()
        }
        
        group.enter()
        getPublicIPv6 { result in
            if case .success(let ip) = result {
                report.publicIPv6 = ip
            } else {
                report.publicIPv6 = "Not available"
            }
            group.leave()
        }
        
        // Test server connectivity
        group.enter()
        testServerConnectivity(host: serverAddress, port: serverPort) { result in
            if case .success(let connectivity) = result {
                report.serverConnectivity = connectivity
            }
            group.leave()
        }
        
        // Test peer connectivity
        for peer in peers {
            if !peer.ipv6.isEmpty && peer.ipv6 != "::" {
                group.enter()
                testIPv6Connectivity(ipv6: peer.ipv6, port: peer.port) { result in
                    if case .success(let connectivity) = result {
                        report.peerConnectivity[peer.identity] = PeerConnectivity(
                            identity: peer.identity,
                            ipv6Connectivity: connectivity,
                            ipv4Connectivity: nil
                        )
                    }
                    group.leave()
                }
            }
            
            if !peer.stunIP.isEmpty && peer.stunIP != "0.0.0.0" {
                group.enter()
                testIPv4Connectivity(ip: peer.stunIP, port: peer.stunPort) { result in
                    if case .success(let connectivity) = result {
                        if report.peerConnectivity[peer.identity] == nil {
                            report.peerConnectivity[peer.identity] = PeerConnectivity(
                                identity: peer.identity,
                                ipv6Connectivity: nil,
                                ipv4Connectivity: connectivity
                            )
                        } else {
                            report.peerConnectivity[peer.identity]?.ipv4Connectivity = connectivity
                        }
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(report)
        }
    }
}

// MARK: - Models

struct ConnectivityResult {
    let connected: Bool
    let latency: Double? // in milliseconds
    let error: String?
}

struct PeerConnectivity {
    let identity: String
    var ipv6Connectivity: ConnectivityResult?
    var ipv4Connectivity: ConnectivityResult?
}

struct NetworkDiagnosticsReport {
    var publicIPv4: String = "Checking..."
    var publicIPv6: String = "Checking..."
    var serverConnectivity: ConnectivityResult?
    var peerConnectivity: [String: PeerConnectivity] = [:]
}

// MARK: - Errors

enum NetworkDiagnosticsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noIPv6
    case invalidIPv6
    case invalidIPv4
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noIPv6:
            return "IPv6 not available"
        case .invalidIPv6:
            return "Invalid IPv6 address"
        case .invalidIPv4:
            return "Invalid IPv4 address"
        }
    }
}


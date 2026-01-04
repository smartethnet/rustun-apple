import Foundation
import Darwin

// 全局变量用于信号处理
private var globalClient: RustunClient?

// 命令行参数解析
struct ClientArgs {
    let serverAddress: String
    let serverPort: UInt16
    let identity: String
    let cryptoConfig: String
    let keepaliveInterval: TimeInterval
    
    static func parse() -> ClientArgs? {
        let args = CommandLine.arguments
        
        guard args.count >= 5 else {
            print("Usage: \(args[0]) <server> <port> <identity> <crypto> [keepalive_interval]")
            print("Example: \(args[0]) 127.0.0.1 8080 client-01 chacha20:secretkey 10")
            return nil
        }
        
        let serverAddress = args[1]
        guard let port = UInt16(args[2]) else {
            print("Error: Invalid port number")
            return nil
        }
        let identity = args[3]
        let cryptoConfig = args[4]
        let keepaliveInterval = args.count > 5 ? TimeInterval(args[5]) ?? 10.0 : 10.0
        
        return ClientArgs(
            serverAddress: serverAddress,
            serverPort: port,
            identity: identity,
            cryptoConfig: cryptoConfig,
            keepaliveInterval: keepaliveInterval
        )
    }
}

// 主函数
func main() {
    guard let args = ClientArgs.parse() else {
        exit(1)
    }
    
    print("====================================")
    print("  Rustun VPN Client Test")
    print("====================================")
    print("Server: \(args.serverAddress):\(args.serverPort)")
    print("Identity: \(args.identity)")
    print("Crypto: \(args.cryptoConfig)")
    print("Keepalive Interval: \(args.keepaliveInterval)s")
    print("====================================")
    print()
    
    let client = RustunClient(
        serverAddress: args.serverAddress,
        serverPort: args.serverPort,
        identity: args.identity,
        cryptoConfig: args.cryptoConfig,
        keepaliveInterval: args.keepaliveInterval
    )
    
    // 保存到全局变量用于信号处理
    globalClient = client
    
    // 设置回调
    client.onHandshakeReply = { reply in
        print("\n✅ Handshake Reply Received:")
        print("   Private IP: \(reply.privateIP)")
        print("   Mask: \(reply.mask)")
        print("   Gateway: \(reply.gateway)")
        print("   Peer Details: \(reply.peerDetails.count)")
        for (index, peer) in reply.peerDetails.enumerated() {
            print("   [\(index + 1)] \(peer.identity) - \(peer.privateIP)")
        }
        print()
    }
    
    client.onDataFrame = { dataFrame in
        log(.debug, "Received data frame: \(dataFrame.payload.count) bytes")
    }
    
    client.onKeepAlive = { keepAlive in
        log(.debug, "Received keepalive: \(keepAlive.peerDetails.count) peers")
    }
    
    client.onDisconnected = {
        log(.info, "Disconnected from server")
    }
    
    // 连接
    log(.info, "Connecting to server...")
    client.run(onReady: { error in
        if let error = error {
            log(.error, "Connection failed: \(error.localizedDescription)")
            print("\n❌ Connection error occurred. Exiting...")
            exit(1)
        } else {
            log(.info, "Connected successfully, waiting for handshake reply...")
        }
    })
    
    // 保持运行
    print("\nPress Ctrl+C to exit...\n")
    
    // 设置信号处理（使用全局变量）
    globalClient = client
    
    // 使用 DispatchSource 处理信号
    let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    signalSource.setEventHandler {
        print("\n\nDisconnecting...")
        globalClient?.close()
        exit(0)
    }
    signalSource.resume()
    signal(SIGINT, SIG_IGN) // 忽略默认处理，使用我们的处理
    
    // 运行主循环
    RunLoop.main.run()
}

// 运行主函数
main()


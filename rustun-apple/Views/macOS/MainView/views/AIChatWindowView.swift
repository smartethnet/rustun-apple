
#if os(macOS)
import SwiftUI
import MarkdownUI
import AppKit

// MARK: - AI Chat Window View (独立窗口)
struct AIChatWindowView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSubmitting = false
    @State private var showingSettingsPrompt = false
    @State private var currentStreamingMessageId: UUID?
    @State private var thinkingMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("AI Assistant")
                        .font(.headline)
                }
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PlatformColors.controlBackground)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if messages.isEmpty {
                            WelcomeView(onAction: { action in
                                sendQuickAction(action)
                            })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 32)
                        } else {
                            ForEach(messages) { message in
                                // Don't show empty assistant messages when thinking indicator is shown
                                if !(message.role == .assistant && message.content.isEmpty && thinkingMessage != nil) {
                                    ChatBubble(message: message)
                                        .id(message.id)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                            }
                            
                            // Show thinking indicator
                            if let thinking = thinkingMessage {
                                ThinkingIndicator(message: thinking)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: messages.last?.content) { _ in
                    // Auto-scroll when streaming content updates
                    if let lastMessage = messages.last, lastMessage.role == .assistant {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input Bar
            AIInputBar(
                inputText: $inputText,
                isSubmitting: $isSubmitting,
                onSubmit: submitAIQuestion
            )
        }
        .background(PlatformColors.windowBackground)
        .frame(minWidth: 800, idealWidth: 900, minHeight: 600, idealHeight: 700)
        .alert("AI Settings Required", isPresented: $showingSettingsPrompt) {
            Button("Cancel", role: .cancel) { }
            Button("Go to Settings") {
                // 可以发送通知让主窗口切换到设置页面
            }
        } message: {
            Text("Please configure your AI model and API key in Settings before using AI features.")
        }
    }
    
    private func sendQuickAction(_ action: String) {
        inputText = action
        submitAIQuestion()
    }
    
    private func submitAIQuestion() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isSubmitting else { return }
        
        // Check if AI settings are configured
        let settings = AppSettings.load()
        if settings.modelKey.isEmpty {
            showingSettingsPrompt = true
            return
        }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: question)
        messages.append(userMessage)
        
        // Clear input
        let currentQuestion = inputText
        inputText = ""
        
        isSubmitting = true
        
        // Create placeholder for streaming response
        let streamingMessageId = UUID()
        currentStreamingMessageId = streamingMessageId
        let placeholderMessage = ChatMessage(
            id: streamingMessageId,
            role: .assistant,
            content: ""
        )
        messages.append(placeholderMessage)
        
        // Convert chat messages to conversation history (excluding the placeholder we just added)
        let history = Array(messages.dropLast())
        
        // Call AI service with streaming
        AIService.shared.sendMessageStream(currentQuestion, conversationHistory: history, onChunk: { chunk in
            DispatchQueue.main.async {
                // Clear thinking message when content starts streaming
                thinkingMessage = nil
                
                // Update the streaming message
                if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                    messages[index] = ChatMessage(
                        id: streamingMessageId,
                        role: .assistant,
                        content: messages[index].content + chunk
                    )
                }
            }
        }, onComplete: { result in
            DispatchQueue.main.async {
                isSubmitting = false
                currentStreamingMessageId = nil
                thinkingMessage = nil
                
                switch result {
                case .success(let fullResponse):
                    // Update final message
                    if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                        messages[index] = ChatMessage(
                            id: streamingMessageId,
                            role: .assistant,
                            content: fullResponse
                        )
                    }
                    
                case .failure(let error):
                    let errorMessage: String
                    if let aiError = error as? AIServiceError {
                        errorMessage = aiError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    // Replace streaming message with error
                    if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                        messages[index] = ChatMessage(
                            id: streamingMessageId,
                            role: .assistant,
                            content: "❌ Error: \(errorMessage)"
                        )
                    }
                }
            }
        }, onThinking: { message in
            DispatchQueue.main.async {
                thinkingMessage = message
            }
        })
    }
}

// MARK: - Thinking Indicator
struct ThinkingIndicator: View {
    let message: String
    @State private var animationPhase: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // AI avatar
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.blue.gradient))
                .frame(width: 32, height: 32)
            
            // Thinking message with animation
            HStack(spacing: 4) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Animated dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                            .opacity(animationPhase == index ? 1.0 : 0.3)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(PlatformColors.controlBackground)
            )
            
            Spacer()
        }
        .onAppear {
            // Animate dots
            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onAction: (String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Rustun VPN AI Assistant")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("您的智能VPN助手")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Project Introduction
                WelcomeSection(
                    icon: "info.circle.fill",
                    title: "关于 Rustun",
                    content: """
                    Rustun 是一个基于 Rust 构建的开源 VPN 隧道，具有以下特点：
                    
                    • P2P 直连：支持 IPv6 和 STUN 打洞，自动选择最佳路径
                    • 智能路由：自动选择最低延迟的连接方式
                    • 多租户隔离：支持多个团队或业务单元的网络隔离
                    • 安全加密：支持 ChaCha20-Poly1305、AES-256-GCM 等加密方式
                    • 跨平台支持：macOS、iOS、Windows、Linux 全平台
                    """
                )
                
                // Getting Started
                WelcomeSection(
                    icon: "play.circle.fill",
                    title: "如何开始使用",
                    content: """
                    1. **配置 VPN 连接**
                       • 点击主界面的"添加 VPN"按钮
                       • 填写服务器地址、端口、身份标识等信息
                       • 配置加密方式和密钥
                    
                    2. **连接 VPN**
                       • 在主界面找到配置好的 VPN
                       • 点击连接开关，等待连接成功
                    
                    3. **查看连接状态**
                       • 连接成功后，可以查看虚拟 IP、连接时间等信息
                       • 在"网络"标签页查看所有 peers 的连接状态
                    """
                )
                
                // Troubleshooting
                WelcomeSection(
                    icon: "wrench.and.screwdriver.fill",
                    title: "遇到问题时",
                    content: """
                    如果连接不符合预期，可以尝试以下诊断步骤：
                    
                    • **检查连接状态**：查看当前 VPN 连接是否正常
                    • **查看日志**：检查是否有错误或警告信息
                    • **网络诊断**：测试与服务器的连通性和网络状态
                    • **网段冲突检测**：检查本地网段是否与 peers 的 CIDR 冲突
                    
                    您可以直接问我："检查连接状态"、"查看日志"、"执行网络诊断"等。
                    """
                )
                
                // Example Questions
                VStack(alignment: .leading, spacing: 12) {
                    Text("您可以这样问我：")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ExampleQuestionButton(
                            question: "检查一下连接状态",
                            action: { onAction("检查连接状态") }
                        )
                        ExampleQuestionButton(
                            question: "查看最近的日志，有没有错误？",
                            action: { onAction("查看日志并检查是否有错误") }
                        )
                        ExampleQuestionButton(
                            question: "执行网络诊断",
                            action: { onAction("执行网络诊断") }
                        )
                        ExampleQuestionButton(
                            question: "检查网段冲突",
                            action: { onAction("检查网段冲突") }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            .frame(maxWidth: 600)
        }
    }
}

// MARK: - Welcome Section
struct WelcomeSection: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PlatformColors.controlBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PlatformColors.separator.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - Example Question Button
struct ExampleQuestionButton: View {
    let question: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "message.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(question)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(PlatformColors.controlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PlatformColors.separator, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window Manager
class AIChatWindowManager {
    static let shared = AIChatWindowManager()
    private var window: NSWindow?
    
    private init() {}
    
    func showWindow() {
        // 如果窗口已存在，则激活它
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建新窗口
        let contentView = AIChatWindowView()
        let hostingView = NSHostingController(rootView: contentView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.contentViewController = hostingView
        newWindow.title = "AI Assistant"
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.isReleasedWhenClosed = false
        
        // 窗口关闭时清理引用
        newWindow.delegate = WindowDelegate { [weak self] in
            self?.window = nil
        }
        
        window = newWindow
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        window?.close()
        window = nil
    }
}

// MARK: - Window Delegate
class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
#endif


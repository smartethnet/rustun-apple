import SwiftUI
import MarkdownUI
import SwiftyMarkdown
import Foundation

#if os(macOS)
// MARK: - AI Input Bar
struct AIInputBar: View {
    @Binding var inputText: String
    @Binding var isSubmitting: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    TextField("Ask me anything...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(PlatformColors.controlBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(PlatformColors.separator, lineWidth: 1)
                                )
                        )
                        .onSubmit {
                            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSubmit()
                            }
                        }
                        .disabled(isSubmitting)
                }
                
                Button(action: onSubmit) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .frame(width: 36, height: 36)
                .cornerRadius(18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(PlatformColors.windowBackground)
    }
}

// MARK: - AI Chat Window
struct AIChatWindow: View {
    @Binding var messages: [ChatMessage]
    @Binding var isPresented: Bool
    
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
                    isPresented = false
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
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue.opacity(0.6))
                                Text("Start a conversation")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
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
            }
        }
        .background(PlatformColors.windowBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chat Bubble
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 用户消息 - 头像在右侧
            if message.role == .user {
                Spacer()
                
                // 消息内容
                VStack(alignment: .trailing, spacing: 4) {
                    Markdown(message.content)
                }
                
                // 用户头像
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
            
            // AI消息 - 头像在左侧
            if message.role == .assistant {
                // AI头像
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.blue.gradient))
                    .frame(width: 32, height: 32)
                
                // 消息内容
                VStack(alignment: .leading, spacing: 4) {
                    Markdown(message.content)
                }
                
                Spacer()
            }
        }
    }
}

#endif

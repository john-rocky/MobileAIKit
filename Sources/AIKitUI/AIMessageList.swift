import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIMessageList: View {
    public let messages: [Message]
    public let streamingText: String

    public init(messages: [Message], streamingText: String = "") {
        self.messages = messages
        self.streamingText = streamingText
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if !streamingText.isEmpty {
                        MessageBubble(message: .assistant(streamingText))
                            .id("streaming")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: streamingText) { _, _ in
                if !streamingText.isEmpty {
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
struct MessageBubble: View {
    let message: Message

    var alignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    var backgroundStyle: AnyShapeStyle {
        switch message.role {
        case .user: return AnyShapeStyle(.tint.opacity(0.18))
        case .assistant: return AnyShapeStyle(.secondary.opacity(0.12))
        case .system: return AnyShapeStyle(.orange.opacity(0.12))
        case .tool: return AnyShapeStyle(.green.opacity(0.12))
        }
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            if message.role != .user {
                Text(headerText).font(.caption).foregroundStyle(.secondary)
            }
            Text(message.content)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            if !message.attachments.isEmpty {
                Text("\(message.attachments.count) attachment(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !message.toolCalls.isEmpty {
                ForEach(message.toolCalls) { call in
                    Label("\(call.name)(…)", systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    var headerText: String {
        switch message.role {
        case .system: return "System"
        case .assistant: return "Assistant"
        case .tool: return "Tool · \(message.name ?? "")"
        case .user: return "You"
        }
    }
}

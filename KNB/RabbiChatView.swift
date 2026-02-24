//
//  RabbiChatView.swift
//  KNB
//
//  Created by AI Assistant on 2/24/26.
//

import SwiftUI
import UIKit

private struct RabbiChatMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let isOutgoing: Bool
    let timestamp: Date
}

private enum RabbiChatRow {
    case separator(String)
    case message(RabbiChatMessage)
}

private enum RabbiChatFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct RabbiChatView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    let currentUser: User
    let threadOwnerEmail: String
    let threadDisplayName: String?
    let directRecipientEmail: String?
    let directRecipientName: String?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isComposerFocused: Bool

    @State private var draftMessage = ""
    @State private var isSending = false
    @State private var isRabbiTyping = false
    @State private var showContent = false
    @State private var driftX: CGFloat = 0
    @State private var driftY: CGFloat = 0
    @State private var shimmerPhase: CGFloat = 0
    @State private var avatarPulse = false
    @State private var sendPress = false
    @State private var messages: [RabbiChatMessage] = []
    @State private var showListenerError = false
    @State private var listenerErrorMessage = ""
    @State private var bottomMarkerMinY: CGFloat = 0
    @State private var scrollViewportHeight: CGFloat = 0
    private let bottomAnchorId = "rabbi-chat-bottom-anchor"

    init(
        firestoreManager: FirestoreManager,
        currentUser: User,
        threadOwnerEmail: String,
        threadDisplayName: String?,
        directRecipientEmail: String? = nil,
        directRecipientName: String? = nil
    ) {
        self.firestoreManager = firestoreManager
        self.currentUser = currentUser
        self.threadOwnerEmail = threadOwnerEmail
        self.threadDisplayName = threadDisplayName
        self.directRecipientEmail = directRecipientEmail
        self.directRecipientName = directRecipientName
    }

    private var isRabbiViewer: Bool {
        firestoreManager.isRabbiAccount(email: currentUser.email)
    }

    private var isDirectChatMode: Bool {
        guard let directRecipientEmail else { return false }
        return !directRecipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var chatTitle: String {
        if isDirectChatMode {
            let provided = (threadDisplayName ?? directRecipientName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !provided.isEmpty {
                return provided
            }
            return directRecipientEmail ?? "Chat"
        }

        if isRabbiViewer {
            let cleaned = threadDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return cleaned.isEmpty ? threadOwnerEmail : cleaned
        }
        return "Chat with Rabbi"
    }

    private var chatSubtitle: String {
        if isDirectChatMode {
            return directRecipientEmail ?? "Direct message"
        }

        if isRabbiViewer {
            return threadOwnerEmail
        }
        return isRabbiTyping ? "Typing..." : "Typically replies quickly"
    }

    private var canSend: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private var shouldShowJumpToPresentButton: Bool {
        guard messages.count > 2, scrollViewportHeight > 0 else { return false }
        let distanceFromBottom = abs(bottomMarkerMinY - scrollViewportHeight)
        return distanceFromBottom > 40
    }

    private var chatRows: [RabbiChatRow] {
        let sorted = messages.sorted { $0.timestamp < $1.timestamp }
        var rows: [RabbiChatRow] = []
        var previousDayStart: Date?
        let calendar = Calendar.current

        for message in sorted {
            let dayStart = calendar.startOfDay(for: message.timestamp)
            if previousDayStart != dayStart {
                rows.append(.separator(dateLabel(for: message.timestamp)))
                previousDayStart = dayStart
            }
            rows.append(.message(message))
        }

        return rows
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TelegramDoodleBackground(
                    driftX: driftX,
                    driftY: driftY,
                    shimmerPhase: shimmerPhase
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ZStack(alignment: .bottomTrailing) {
                            ScrollView {
                                VStack(spacing: 4) {
                                    ForEach(Array(chatRows.enumerated()), id: \.offset) { index, row in
                                        switch row {
                                        case .separator(let label):
                                            RabbiDateChip(text: label)
                                                .padding(.vertical, 3)
                                                .transition(.opacity)

                                        case .message(let message):
                                            TelegramChatBubble(
                                                message: message,
                                                entryDelay: min(0.18, Double(index) * 0.03)
                                            )
                                        }
                                    }

                                    if isRabbiTyping {
                                        HStack {
                                            TelegramTypingBubble()
                                            Spacer(minLength: 44)
                                        }
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    }

                                    Color.clear
                                        .frame(height: 1)
                                        .id(bottomAnchorId)
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: RabbiBottomMarkerMinYPreferenceKey.self,
                                                    value: geo.frame(in: .named("rabbiChatScroll")).minY
                                                )
                                            }
                                        )
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                            }
                            .coordinateSpace(name: "rabbiChatScroll")
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: RabbiScrollViewportHeightPreferenceKey.self,
                                        value: geo.size.height
                                    )
                                }
                            )
                            .scrollIndicators(.hidden)
                            .scrollDismissesKeyboard(.interactively)
                            .onPreferenceChange(RabbiBottomMarkerMinYPreferenceKey.self) { value in
                                bottomMarkerMinY = value
                            }
                            .onPreferenceChange(RabbiScrollViewportHeightPreferenceKey.self) { value in
                                scrollViewportHeight = value
                            }
                            .onAppear {
                                scrollToBottom(proxy, animated: false)
                            }
                            .onChange(of: messages.count) { _, _ in
                                scrollToBottom(proxy, animated: true)
                            }
                            .onChange(of: isRabbiTyping) { _, typing in
                                guard typing else { return }
                                scrollToBottom(proxy, animated: true)
                            }

                            if shouldShowJumpToPresentButton {
                                Button {
                                    scrollToBottom(proxy, animated: true)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1.1
                                                    )
                                            )

                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.16), Color.black.opacity(0.12)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .padding(3.5)

                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.95))
                                    }
                                    .frame(width: 46, height: 46)
                                    .shadow(color: Color.black.opacity(0.32), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 12)
                                .padding(.bottom, 14)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composerBar
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 6)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.26)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 14)
                .scaleEffect(showContent ? 1 : 0.99)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                            )
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.12, green: 0.56, blue: 0.98),
                                        Color(red: 0.2, green: 0.78, blue: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text("R")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: Color.cyan.opacity(avatarPulse ? 0.44 : 0.14), radius: avatarPulse ? 16 : 7)
                            .scaleEffect(avatarPulse ? 1.05 : 0.98)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(chatTitle)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(chatSubtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    showContent = true
                }
                startListeningToMessages()
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    driftX = 26
                    driftY = -18
                }
                withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    avatarPulse = true
                }
            }
            .onDisappear {
                firestoreManager.stopListeningToRabbiMessages()
                firestoreManager.stopListeningToDirectMessages()
            }
            .alert("Chat Connection Issue", isPresented: $showListenerError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(listenerErrorMessage)
            }
        }
    }

    private var composerBar: some View {
        return HStack(alignment: .bottom, spacing: 10) {
            TextField("Message...", text: $draftMessage, axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .tint(Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.035))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isComposerFocused ? 0.35 : 0.2),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.1
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.03), Color.black.opacity(0.11)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: Color.white.opacity(0.08), radius: 1.2, x: 0, y: -0.5)
                )
                .animation(.easeInOut(duration: 0.2), value: isComposerFocused)

            Button {
                guard canSend else { return }
                sendMessage()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.24), lineWidth: 1.1)
                        )

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: canSend
                                    ? [Color(red: 0.2, green: 0.46, blue: 0.98), Color(red: 0.39, green: 0.42, blue: 1.0)]
                                    : [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(4.8)

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? Color.white : Color.white.opacity(0.65))
                        .offset(x: 0.5, y: -0.5)
                }
                .frame(width: 50, height: 50)
                .shadow(color: Color.white.opacity(canSend ? 0.13 : 0.05), radius: 2, x: 0, y: -0.5)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .scaleEffect(sendPress ? 0.86 : (canSend ? 1 : 0.96))
            .rotationEffect(.degrees(sendPress ? -10 : 0))
            .animation(.spring(response: 0.24, dampingFraction: 0.66), value: sendPress)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: canSend)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
    }

    private func sendMessage() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        isComposerFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
            sendPress = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                sendPress = false
            }
        }
        draftMessage = ""
        isSending = true

        Task {
            let didSend: Bool
            if isDirectChatMode, let directRecipientEmail {
                didSend = await firestoreManager.sendDirectMessage(
                    content: trimmed,
                    sender: currentUser,
                    recipientEmail: directRecipientEmail,
                    recipientName: directRecipientName ?? threadDisplayName
                )
            } else {
                didSend = await firestoreManager.sendRabbiMessage(
                    content: trimmed,
                    sender: currentUser,
                    threadOwnerEmail: threadOwnerEmail
                )
            }

            await MainActor.run {
                isSending = false
                if !didSend {
                    // Restore the text so the user can retry.
                    draftMessage = trimmed
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func startListeningToMessages() {
        if isDirectChatMode, let directRecipientEmail {
            firestoreManager.startListeningToDirectMessages(
                currentUserEmail: currentUser.email,
                otherUserEmail: directRecipientEmail
            ) { records in
                let currentViewerEmail = normalizedIdentityEmail(currentUser.email)
                let mapped = records.map { record in
                    RabbiChatMessage(
                        id: record.id,
                        text: record.content,
                        isOutgoing: normalizedIdentityEmail(record.senderEmail) == currentViewerEmail,
                        timestamp: record.timestamp
                    )
                }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    messages = mapped
                }
            } onError: { errorDescription in
                listenerErrorMessage = "Messages failed to load: \(errorDescription)"
                showListenerError = true
            }
        } else {
            firestoreManager.startListeningToRabbiMessages(
                threadOwnerEmail: threadOwnerEmail
            ) { records in
                let currentViewerEmail = normalizedIdentityEmail(currentUser.email)
                let mapped = records.map { record in
                    RabbiChatMessage(
                        id: record.id,
                        text: record.content,
                        isOutgoing: normalizedIdentityEmail(record.senderEmail) == currentViewerEmail,
                        timestamp: record.timestamp
                    )
                }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    messages = mapped
                }
            } onError: { errorDescription in
                listenerErrorMessage = "Messages failed to load: \(errorDescription)"
                showListenerError = true
            }
        }
    }

    private func normalizedIdentityEmail(_ email: String) -> String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@googlemail.com", with: "@gmail.com")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                proxy.scrollTo(bottomAnchorId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorId, anchor: .bottom)
        }
    }

    private func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct RabbiDateChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
    }
}

private struct TelegramChatBubble: View {
    let message: RabbiChatMessage
    let entryDelay: Double
    @State private var isVisible = false
    @State private var isPressed = false

    private var maxBubbleWidth: CGFloat {
        UIScreen.main.bounds.width * 0.7
    }

    private var metadataReservedWidth: CGFloat {
        let timeText = RabbiChatFormatters.time.string(from: message.timestamp) as NSString
        let timeWidth = timeText.size(
            withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .regular)]
        ).width
        let checkWidth: CGFloat = message.isOutgoing ? 12 : 0
        return max(34, ceil(timeWidth + checkWidth + 8))
    }
    
    private var outgoingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.35, blue: 1.0),
                Color(red: 0.55, green: 0.45, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var incomingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.15, blue: 0.15),
                Color(red: 0.2, green: 0.2, blue: 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isOutgoing {
                Spacer(minLength: 0)
                bubbleContent
            } else {
                bubbleContent
                Spacer(minLength: 0)
            }
        }
        .id(message.id)
        .opacity(isVisible ? 1 : 0)
        .offset(
            x: isVisible ? 0 : (message.isOutgoing ? 8 : -8),
            y: isVisible ? 0 : 4
        )
        .scaleEffect(isVisible ? 1 : 0.97, anchor: message.isOutgoing ? .trailing : .leading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2).delay(entryDelay)) {
                isVisible = true
            }
        }
    }

    private var bubbleContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(message.text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, metadataReservedWidth)
                .padding(.bottom, 1)

            HStack(spacing: 2) {
                Text(RabbiChatFormatters.time.string(from: message.timestamp))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))

                if message.isOutgoing {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(.bottom, 1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            (message.isOutgoing ? outgoingGradient : incomingGradient)
                .clipShape(SproutBubbleShape(myMessage: message.isOutgoing))
                .overlay(
                    SproutBubbleShape(myMessage: message.isOutgoing)
                        .stroke(Color.white.opacity(message.isOutgoing ? 0.1 : 0.08), lineWidth: 0.8)
                )
        )
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 1)
        .frame(maxWidth: maxBubbleWidth, alignment: message.isOutgoing ? .trailing : .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

private struct SproutBubbleShape: Shape {
    let myMessage: Bool

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                myMessage ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}

private struct TelegramTypingBubble: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.84))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1.12 : 0.7)
                    .opacity(animate ? 1 : 0.32)
                    .animation(
                        .easeInOut(duration: 0.46)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.14),
                        value: animate
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
        .onAppear { animate = true }
    }
}

private struct TelegramDoodleBackground: View {
    let driftX: CGFloat
    let driftY: CGFloat
    let shimmerPhase: CGFloat

    // If you add a real wallpaper image in Assets with this exact name,
    // it will be used automatically.
    private let wallpaperAssetName = "RabbiChatWallpaper"

    private let symbols = [
        "paperplane", "paperclip", "gamecontroller", "camera", "envelope", "star",
        "sparkles", "music.note", "heart", "circle.grid.2x2", "headphones",
        "basketball", "message", "message.badge", "book", "leaf", "moon.stars",
        "sun.max", "face.smiling", "wifi", "bolt", "gift", "cloud"
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.02, green: 0.03, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if UIImage(named: wallpaperAssetName) != nil {
                    Color.black
                    Image(wallpaperAssetName)
                        .resizable(resizingMode: .tile)
                        .opacity(0.4)
                        .scaleEffect(1.01)
                        .offset(x: driftX * 0.18, y: driftY * 0.18)
                } else {
                    ForEach(0..<220, id: \.self) { idx in
                        let column = idx % 14
                        let row = idx / 14
                        let spacingX = max(28.0, geometry.size.width / 14.0)
                        let spacingY = 72.0
                        let jitterX = CGFloat((idx * 37) % 18) - 9
                        let jitterY = CGFloat((idx * 51) % 22) - 11
                        let tintBoost = idx % 5 == 0
                        let size = CGFloat(11 + ((idx * 7) % 12))

                        Image(systemName: symbols[idx % symbols.count])
                            .font(.system(size: size, weight: .regular))
                            .foregroundStyle(
                                tintBoost
                                    ? Color(red: 0.74, green: 0.4, blue: 1.0).opacity(0.16)
                                    : Color.white.opacity(0.08)
                            )
                            .rotationEffect(.degrees(Double((idx * 19) % 360)))
                            .position(
                                x: CGFloat(column) * spacingX + jitterX,
                                y: CGFloat(row) * spacingY + jitterY
                            )
                            .offset(
                                x: driftX * (0.04 + CGFloat((idx % 9)) * 0.004),
                                y: driftY * (0.05 + CGFloat((idx % 7)) * 0.004)
                            )
                    }
                }

                RadialGradient(
                    colors: [
                        Color(red: 0.74, green: 0.32, blue: 0.98).opacity(0.22),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 40,
                    endRadius: 380
                )
                .offset(x: 35 + (shimmerPhase * 35), y: -40)
                .blendMode(.screen)
                .opacity(UIImage(named: wallpaperAssetName) != nil ? 0 : 1)

                RadialGradient(
                    colors: [
                        Color(red: 0.22, green: 0.38, blue: 0.98).opacity(0.18),
                        Color.clear
                    ],
                    center: .bottomLeading,
                    startRadius: 50,
                    endRadius: 430
                )
                .offset(x: -28 - (shimmerPhase * 28), y: 20)
                .blendMode(.screen)
                .opacity(UIImage(named: wallpaperAssetName) != nil ? 0 : 1)

                LinearGradient(
                    colors: [Color.black.opacity(0.18), Color.black.opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

private struct RabbiBottomMarkerMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RabbiScrollViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    RabbiChatView(
        firestoreManager: FirestoreManager(),
        currentUser: User(
            name: "Preview User",
            email: "preview@example.com",
            totalPledged: 0,
            isAdmin: false,
            notificationPrefs: NotificationPreferences()
        ),
        threadOwnerEmail: "preview@example.com",
        threadDisplayName: nil
    )
}

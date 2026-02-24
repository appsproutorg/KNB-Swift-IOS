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

    private var isRabbiViewer: Bool {
        firestoreManager.isRabbiAccount(email: currentUser.email)
    }

    private var chatTitle: String {
        if isRabbiViewer {
            let cleaned = threadDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return cleaned.isEmpty ? threadOwnerEmail : cleaned
        }
        return "Chat with Rabbi"
    }

    private var chatSubtitle: String {
        if isRabbiViewer {
            return threadOwnerEmail
        }
        return isRabbiTyping ? "Typing..." : "Typically replies quickly"
    }

    private var canSend: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
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
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(chatRows.enumerated()), id: \.offset) { index, row in
                                    switch row {
                                    case .separator(let label):
                                        RabbiDateChip(text: label)
                                            .padding(.vertical, 6)
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
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 12)
                            .padding(.bottom, 14)
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
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
                    }

                    composerBar
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
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
            }
            .alert("Chat Connection Issue", isPresented: $showListenerError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(listenerErrorMessage)
            }
        }
    }

    private var composerBar: some View {
        return HStack(spacing: 8) {
            TextField("Message Rabbi...", text: $draftMessage, axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .tint(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isComposerFocused ? 0.32 : 0.14),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                    )
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
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: canSend
                                    ? [Color(red: 0.3, green: 0.2, blue: 0.96), Color(red: 0.35, green: 0.54, blue: 1.0)]
                                    : [Color.white.opacity(0.14), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(4)

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(canSend ? Color.white : Color.white.opacity(0.65))
                        .offset(x: 0.5, y: -0.5)
                }
                .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .scaleEffect(sendPress ? 0.82 : (canSend ? 1 : 0.96))
            .rotationEffect(.degrees(sendPress ? -14 : 0))
            .animation(.spring(response: 0.24, dampingFraction: 0.66), value: sendPress)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: canSend)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.06), Color.black.opacity(0.16)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
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
            let didSend = await firestoreManager.sendRabbiMessage(
                content: trimmed,
                sender: currentUser,
                threadOwnerEmail: threadOwnerEmail
            )

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

    private func normalizedIdentityEmail(_ email: String) -> String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@googlemail.com", with: "@gmail.com")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = messages.last else { return }
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
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

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isOutgoing {
                Spacer(minLength: 42)
                bubbleContent
            } else {
                bubbleContent
                Spacer(minLength: 42)
            }
        }
        .id(message.id)
        .opacity(isVisible ? 1 : 0)
        .offset(
            x: isVisible ? 0 : (message.isOutgoing ? 18 : -18),
            y: isVisible ? 0 : 9
        )
        .scaleEffect(isVisible ? 1 : 0.94, anchor: message.isOutgoing ? .trailing : .leading)
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86).delay(entryDelay)) {
                isVisible = true
            }
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(message.text)
                .font(.system(size: 16))
                .foregroundStyle(.white)

            HStack(spacing: 2) {
                Spacer(minLength: 0)
                Text(RabbiChatFormatters.time.string(from: message.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))

                if message.isOutgoing {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: 286, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    message.isOutgoing
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(red: 0.42, green: 0.35, blue: 1.0), Color(red: 0.55, green: 0.45, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.15, blue: 0.15), Color(red: 0.2, green: 0.2, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .clipShape(TelegramBubbleShape(myMessage: message.isOutgoing))
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

private struct TelegramBubbleShape: Shape {
    var myMessage: Bool

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

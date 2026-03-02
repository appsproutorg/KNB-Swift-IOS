//
//  RabbiInboxView.swift
//  KNB
//
//  Created by AI Assistant on 2/24/26.
//

import SwiftUI

struct RabbiInboxView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    let currentUser: User
    var showsCloseButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var threadSummaries: [RabbiChatThreadSummary] = []
    @State private var selectedThread: RabbiChatThreadSummary?
    @State private var showListenerError = false
    @State private var listenerErrorMessage = ""
    @State private var pendingDeleteThread: RabbiChatThreadSummary?
    @State private var deletingThreadOwnerEmail: String?

    private var isLightMode: Bool {
        colorScheme == .light
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: isLightMode
                        ? [Color(red: 0.94, green: 0.95, blue: 0.98), Color(red: 0.98, green: 0.98, blue: 0.99)]
                        : [Color(red: 0.04, green: 0.06, blue: 0.12), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if threadSummaries.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.62) : .white.opacity(0.7))

                        Text("No messages yet")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.86) : .white)

                        Text("User conversations will appear here.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.54) : .white.opacity(0.62))
                    }
                    .padding(.horizontal, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(threadSummaries) { thread in
                                SwipeToDeleteRabbiInboxRow(
                                    thread: thread,
                                    isDeleting: deletingThreadOwnerEmail == thread.threadOwnerEmail,
                                    isInteractionDisabled: deletingThreadOwnerEmail != nil,
                                    onTap: {
                                        selectedThread = thread
                                    },
                                    onDeleteTap: {
                                        pendingDeleteThread = thread
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.8) : .white)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Rabbi Inbox")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.86) : .white)
                        Text("User conversations")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.48) : .white.opacity(0.6))
                    }
                }
            }
            .tint(isLightMode ? .blue : .white)
            .onAppear {
                firestoreManager.startListeningToRabbiInbox(rabbiEmail: currentUser.email) { summaries in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        threadSummaries = summaries
                    }
                } onError: { errorDescription in
                    listenerErrorMessage = "Inbox failed to load: \(errorDescription)"
                    showListenerError = true
                }
            }
            .onDisappear {
                firestoreManager.stopListeningToRabbiInbox()
            }
            .alert("Inbox Connection Issue", isPresented: $showListenerError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(listenerErrorMessage)
            }
            .confirmationDialog(
                "Delete Chat",
                isPresented: Binding(
                    get: { pendingDeleteThread != nil },
                    set: { isPresented in
                        if !isPresented { pendingDeleteThread = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingDeleteThread
            ) { thread in
                Button("Delete Chat", role: .destructive) {
                    deleteThread(thread)
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteThread = nil
                }
            } message: { thread in
                Text("This permanently deletes all messages with \(thread.threadOwnerName) for everyone.")
            }
            .fullScreenCover(item: $selectedThread) { thread in
                RabbiChatView(
                    firestoreManager: firestoreManager,
                    currentUser: currentUser,
                    threadOwnerEmail: thread.threadOwnerEmail,
                    threadDisplayName: thread.threadOwnerName
                )
            }
        }
    }

    private func deleteThread(_ thread: RabbiChatThreadSummary) {
        guard deletingThreadOwnerEmail == nil else { return }

        deletingThreadOwnerEmail = thread.threadOwnerEmail
        pendingDeleteThread = nil

        Task {
            let didDelete = await firestoreManager.deleteRabbiChatThread(
                rabbiEmail: currentUser.email,
                threadOwnerEmail: thread.threadOwnerEmail
            )

            await MainActor.run {
                deletingThreadOwnerEmail = nil

                guard didDelete else {
                    listenerErrorMessage = firestoreManager.errorMessage ?? "Failed to delete chat."
                    showListenerError = true
                    return
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    threadSummaries.removeAll { summary in
                        summary.threadOwnerEmail == thread.threadOwnerEmail
                    }
                }
            }
        }
    }
}

private struct RabbiInboxRow: View {
    let thread: RabbiChatThreadSummary
    let isLightMode: Bool
    var isDeleting: Bool = false

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: thread.lastMessageTimestamp, relativeTo: Date())
    }

    private var initial: String {
        let trimmed = thread.threadOwnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.28, green: 0.44, blue: 0.98), Color(red: 0.42, green: 0.64, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initial.isEmpty ? "U" : initial)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text(thread.threadOwnerName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.84) : .white)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(isLightMode ? .black.opacity(0.55) : .white.opacity(0.72))
                    } else {
                        Text(relativeTime)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.48) : .white.opacity(0.6))
                    }
                }

                Text(thread.threadOwnerEmail)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(isLightMode ? Color.black.opacity(0.48) : .white.opacity(0.58))
                    .lineLimit(1)

                Text(thread.lastMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isLightMode ? Color.black.opacity(0.74) : .white.opacity(0.82))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

private struct SwipeToDeleteRabbiInboxRow: View {
    let thread: RabbiChatThreadSummary
    let isDeleting: Bool
    let isInteractionDisabled: Bool
    let onTap: () -> Void
    let onDeleteTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var offsetX: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var revealPulse = false

    private let revealWidth: CGFloat = 92

    private var isLightMode: Bool {
        colorScheme == .light
    }

    private var effectiveOffset: CGFloat {
        max(-revealWidth, min(0, offsetX + dragOffset))
    }

    private var revealAmount: CGFloat {
        max(0, min(revealWidth, -effectiveOffset))
    }

    private var revealProgress: CGFloat {
        revealWidth > 0 ? revealAmount / revealWidth : 0
    }

    private var actionScale: CGFloat {
        let base = 0.84 + (0.16 * revealProgress)
        return revealPulse ? base * 1.05 : base
    }

    private var actionOffsetX: CGFloat {
        12 * (1 - revealProgress)
    }

    private var actionRotation: Double {
        Double(10 * (1 - revealProgress))
    }

    private var actionBlur: CGFloat {
        1.8 * (1 - revealProgress)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Button {
                    guard !isInteractionDisabled else { return }
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        offsetX = 0
                        dragOffset = 0
                    }
                    onDeleteTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(isLightMode ? 0.16 : 0.1))
                            .blur(radius: 10)
                            .scaleEffect(0.9 + (0.25 * revealProgress))
                            .opacity(Double(revealProgress))

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.28, blue: 0.34), Color(red: 0.94, green: 0.2, blue: 0.24)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(isLightMode ? 0.32 : 0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(isLightMode ? 0.22 : 0.36), radius: 8, x: 0, y: 4)

                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: actionOffsetX)
                            .rotationEffect(.degrees(actionRotation))
                            .blur(radius: actionBlur)
                    }
                    .frame(width: 54, height: 54)
                    .scaleEffect(actionScale)
                    .opacity(Double(revealProgress))
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isInteractionDisabled || revealProgress < 0.72)
                .frame(width: revealAmount)
                .frame(maxHeight: .infinity)
            }
            .opacity(revealProgress > 0.001 ? 1 : 0)

            RabbiInboxRow(thread: thread, isLightMode: isLightMode, isDeleting: isDeleting)
                .offset(x: effectiveOffset)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    guard !isInteractionDisabled else { return }
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    guard !isInteractionDisabled else { return }
                    let total = offsetX + value.translation.width
                    let projected = offsetX + value.predictedEndTranslation.width
                    let shouldReveal = total <= -(revealWidth * 0.45) || projected <= -(revealWidth * 0.75)
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.84, blendDuration: 0.1)) {
                        if shouldReveal {
                            offsetX = -revealWidth
                        } else {
                            offsetX = 0
                        }
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture {
            guard !isInteractionDisabled else { return }
            if effectiveOffset < -5 || offsetX < -5 {
                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.86, blendDuration: 0.1)) {
                    offsetX = 0
                    dragOffset = 0
                }
                return
            }
            onTap()
        }
        .onChange(of: offsetX) { _, newValue in
            guard newValue <= -(revealWidth - 0.5) else {
                revealPulse = false
                return
            }

            revealPulse = false
            withAnimation(.easeOut(duration: 0.12)) {
                revealPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeInOut(duration: 0.14)) {
                    revealPulse = false
                }
            }
        }
    }
}

#Preview {
    RabbiInboxView(
        firestoreManager: FirestoreManager(),
        currentUser: User(
            name: "Rabbi",
            email: "acagishtein@gmail.com",
            totalPledged: 0,
            isAdmin: false,
            notificationPrefs: NotificationPreferences()
        )
    )
}

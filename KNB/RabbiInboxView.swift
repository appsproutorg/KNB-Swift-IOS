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

    @Environment(\.dismiss) private var dismiss

    @State private var threadSummaries: [RabbiChatThreadSummary] = []
    @State private var selectedThread: RabbiChatThreadSummary?
    @State private var showListenerError = false
    @State private var listenerErrorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if threadSummaries.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))

                        Text("No messages yet")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("User conversations will appear here.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    .padding(.horizontal, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(threadSummaries) { thread in
                                Button {
                                    selectedThread = thread
                                } label: {
                                    RabbiInboxRow(thread: thread)
                                }
                                .buttonStyle(.plain)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Rabbi Inbox")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("User conversations")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
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
}

private struct RabbiInboxRow: View {
    let thread: RabbiChatThreadSummary

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
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(relativeTime)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text(thread.threadOwnerEmail)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)

                Text(thread.lastMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
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
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
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

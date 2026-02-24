//
//  MemberChatListView.swift
//  KNB
//
//  Created by AI Assistant on 2/24/26.
//

import SwiftUI

struct MemberChatListView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    let currentUser: User
    var showsCloseButton: Bool = false

    @Environment(\.dismiss) private var dismiss

    @State private var directThreadSummaries: [DirectChatThreadSummary] = []
    @State private var directoryUsers: [ChatDirectoryUser] = []
    @State private var selectedDestination: MemberChatDestination?
    @State private var showListenerError = false
    @State private var listenerErrorMessage = ""
    @State private var showComposeSheet = false
    @State private var searchText = ""

    private var isRabbiUser: Bool {
        firestoreManager.isRabbiAccount(email: currentUser.email)
    }

    private var shouldShowPinnedRabbi: Bool {
        !isRabbiUser
    }

    private var composeEntries: [MemberChatEntry] {
        let summariesByEmail = Dictionary(uniqueKeysWithValues: directThreadSummaries.map {
            ($0.otherParticipantEmail, $0)
        })

        var entries: [MemberChatEntry] = directoryUsers.map { user in
            let summary = summariesByEmail[user.email]
            return MemberChatEntry(
                email: user.email,
                name: user.name,
                lastMessage: summary?.lastMessage,
                lastMessageTimestamp: summary?.lastMessageTimestamp
            )
        }

        // Include chats that exist in messages but not yet in local directory cache.
        let existingEmails = Set(entries.map { $0.email })
        for summary in directThreadSummaries where !existingEmails.contains(summary.otherParticipantEmail) {
            entries.append(
                MemberChatEntry(
                    email: summary.otherParticipantEmail,
                    name: summary.otherParticipantName,
                    lastMessage: summary.lastMessage,
                    lastMessageTimestamp: summary.lastMessageTimestamp
                )
            )
        }

        return entries.sorted { lhs, rhs in
            switch (lhs.lastMessageTimestamp, rhs.lastMessageTimestamp) {
            case let (l?, r?):
                if l != r { return l > r }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var activeChatEntries: [MemberChatEntry] {
        let namesByEmail = Dictionary(uniqueKeysWithValues: directoryUsers.map { user in
            (user.email, user.name)
        })

        return directThreadSummaries.map { summary in
            let resolvedName = namesByEmail[summary.otherParticipantEmail] ?? summary.otherParticipantName
            return MemberChatEntry(
                email: summary.otherParticipantEmail,
                name: resolvedName,
                lastMessage: summary.lastMessage,
                lastMessageTimestamp: summary.lastMessageTimestamp
            )
        }
    }

    private var filteredChatEntries: [MemberChatEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return activeChatEntries }
        return activeChatEntries.filter {
            $0.name.lowercased().contains(query) || $0.email.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if shouldShowPinnedRabbi {
                            MemberSectionHeader(title: "Pinned")

                            Button {
                                selectedDestination = .rabbi
                            } label: {
                                MemberPinnedRabbiRow()
                            }
                            .buttonStyle(.plain)
                        } else {
                            MemberSectionHeader(title: "Pinned")

                            Button {
                                selectedDestination = .rabbiInbox
                            } label: {
                                MemberPinnedInboxRow()
                            }
                            .buttonStyle(.plain)
                        }

                        MemberSectionHeader(title: "Chats")
                            .padding(.top, shouldShowPinnedRabbi ? 2 : 0)

                        if filteredChatEntries.isEmpty {
                            Text(
                                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "No chats yet. Tap compose to start one."
                                : "No chats match your search."
                            )
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredChatEntries) { entry in
                                Button {
                                    selectedDestination = .direct(entry)
                                } label: {
                                    MemberChatRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search people")
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundStyle(.white)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Chats")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Messages")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showComposeSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Compose message")
                }
            }
            .onAppear {
                firestoreManager.startListeningToDirectInbox(currentUserEmail: currentUser.email) { summaries in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        directThreadSummaries = summaries
                    }
                } onError: { errorDescription in
                    listenerErrorMessage = "Chats failed to load: \(errorDescription)"
                    showListenerError = true
                }

                Task {
                    let users = await firestoreManager.fetchChatDirectoryUsers(excludingEmail: currentUser.email)
                    await MainActor.run {
                        directoryUsers = users
                    }
                }
            }
            .onDisappear {
                firestoreManager.stopListeningToDirectInbox()
            }
            .alert("Chat Connection Issue", isPresented: $showListenerError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(listenerErrorMessage)
            }
            .sheet(isPresented: $showComposeSheet) {
                MemberComposeChatSheet(entries: composeEntries) { selectedEntry in
                    showComposeSheet = false
                    selectedDestination = .direct(selectedEntry)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $selectedDestination) { destination in
                switch destination {
                case .rabbi:
                    RabbiChatView(
                        firestoreManager: firestoreManager,
                        currentUser: currentUser,
                        threadOwnerEmail: currentUser.email,
                        threadDisplayName: nil
                    )
                case .rabbiInbox:
                    RabbiInboxView(
                        firestoreManager: firestoreManager,
                        currentUser: currentUser
                    )
                case .direct(let entry):
                    RabbiChatView(
                        firestoreManager: firestoreManager,
                        currentUser: currentUser,
                        threadOwnerEmail: currentUser.email,
                        threadDisplayName: entry.name,
                        directRecipientEmail: entry.email,
                        directRecipientName: entry.name
                    )
                }
            }
        }
    }
}

private struct MemberComposeChatSheet: View {
    let entries: [MemberChatEntry]
    let onSelect: (MemberChatEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredEntries: [MemberChatEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.name.lowercased().contains(query) || $0.email.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredEntries.isEmpty {
                            Text("No people found.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredEntries) { entry in
                                Button {
                                    onSelect(entry)
                                    dismiss()
                                } label: {
                                    MemberChatRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search people")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private enum MemberChatDestination: Identifiable {
    case rabbi
    case rabbiInbox
    case direct(MemberChatEntry)

    var id: String {
        switch self {
        case .rabbi:
            return "rabbi"
        case .rabbiInbox:
            return "rabbi-inbox"
        case .direct(let entry):
            return "direct-\(entry.email)"
        }
    }
}

private struct MemberChatEntry: Identifiable, Equatable {
    var id: String { email }
    let email: String
    let name: String
    let lastMessage: String?
    let lastMessageTimestamp: Date?
}

private struct MemberSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.58))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

private struct MemberPinnedRabbiRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.24, green: 0.58, blue: 1.0), Color(red: 0.38, green: 0.72, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Text("R")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("Ask Rabbi")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Pinned")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.46, green: 0.68, blue: 1.0))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.2, green: 0.36, blue: 0.74).opacity(0.2))
                        )
                }
                Text("Typically replies quickly")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct MemberPinnedInboxRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.24, green: 0.58, blue: 1.0), Color(red: 0.38, green: 0.72, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("Rabbi Inbox")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Pinned")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.46, green: 0.68, blue: 1.0))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.2, green: 0.36, blue: 0.74).opacity(0.2))
                        )
                }
                Text("Open Ask-Rabbi conversations")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct MemberChatRow: View {
    let entry: MemberChatEntry

    private var relativeTime: String {
        guard let timestamp = entry.lastMessageTimestamp else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    private var initial: String {
        let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.3, green: 0.45, blue: 0.98), Color(red: 0.48, green: 0.62, blue: 1.0)],
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
                    Text(entry.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if !relativeTime.isEmpty {
                        Text(relativeTime)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Text(entry.email)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)

                if let lastMessage = entry.lastMessage, !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Start a new message")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                }
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
    MemberChatListView(
        firestoreManager: FirestoreManager(),
        currentUser: User(
            name: "Preview User",
            email: "preview@example.com",
            totalPledged: 0,
            isAdmin: false,
            notificationPrefs: NotificationPreferences()
        )
    )
}

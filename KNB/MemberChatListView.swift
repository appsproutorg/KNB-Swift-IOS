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
    @Environment(\.colorScheme) private var colorScheme

    @State private var directThreadSummaries: [DirectChatThreadSummary] = []
    @State private var directoryUsers: [ChatDirectoryUser] = []
    @State private var selectedDestination: MemberChatDestination?
    @State private var showListenerError = false
    @State private var listenerErrorMessage = ""
    @State private var showComposeSheet = false
    @State private var searchText = ""
    @State private var pendingDeleteEntry: MemberChatEntry?
    @State private var deletingChatEmail: String?

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
                                .foregroundStyle(isLightMode ? Color.black.opacity(0.52) : .white.opacity(0.62))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredChatEntries) { entry in
                                SwipeToDeleteChatRow(
                                    entry: entry,
                                    isDeleting: deletingChatEmail == entry.email,
                                    isInteractionDisabled: deletingChatEmail != nil,
                                    onTap: {
                                        selectedDestination = .direct(entry)
                                    },
                                    onDeleteTap: {
                                        pendingDeleteEntry = entry
                                    }
                                )
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
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.8) : .white)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Chats")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.86) : .white)
                        Text("Messages")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.48) : .white.opacity(0.6))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showComposeSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.82) : .white)
                    }
                    .accessibilityLabel("Compose message")
                }
            }
            .tint(isLightMode ? .blue : .white)
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
            .confirmationDialog(
                "Delete Chat",
                isPresented: Binding(
                    get: { pendingDeleteEntry != nil },
                    set: { isPresented in
                        if !isPresented { pendingDeleteEntry = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingDeleteEntry
            ) { entry in
                Button("Delete Chat", role: .destructive) {
                    deleteChat(entry)
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteEntry = nil
                }
            } message: { entry in
                Text("This permanently deletes all messages with \(entry.name) for everyone.")
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

    private func deleteChat(_ entry: MemberChatEntry) {
        guard deletingChatEmail == nil else { return }

        deletingChatEmail = entry.email
        pendingDeleteEntry = nil

        Task {
            let didDelete = await firestoreManager.deleteDirectChatThread(
                currentUserEmail: currentUser.email,
                otherUserEmail: entry.email
            )

            await MainActor.run {
                deletingChatEmail = nil

                guard didDelete else {
                    listenerErrorMessage = firestoreManager.errorMessage ?? "Failed to delete chat."
                    showListenerError = true
                    return
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    directThreadSummaries.removeAll { summary in
                        summary.otherParticipantEmail == entry.email
                    }
                }
            }
        }
    }
}

private struct SwipeToDeleteChatRow: View {
    let entry: MemberChatEntry
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

            MemberChatRow(entry: entry, isDeleting: isDeleting)
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

private struct MemberComposeChatSheet: View {
    let entries: [MemberChatEntry]
    let onSelect: (MemberChatEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""

    private var filteredEntries: [MemberChatEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.name.lowercased().contains(query) || $0.email.lowercased().contains(query)
        }
    }

    private var isLightMode: Bool {
        colorScheme == .light
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: isLightMode
                        ? [Color(red: 0.95, green: 0.96, blue: 0.99), Color(red: 0.99, green: 0.99, blue: 1.0)]
                        : [Color(red: 0.04, green: 0.06, blue: 0.12), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredEntries.isEmpty {
                            Text("No people found.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(isLightMode ? Color.black.opacity(0.52) : .white.opacity(0.62))
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
                    .foregroundStyle(isLightMode ? Color.black.opacity(0.8) : .white)
                }
            }
            .tint(isLightMode ? .blue : .white)
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
    @Environment(\.colorScheme) private var colorScheme

    private var isLightMode: Bool {
        colorScheme == .light
    }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(isLightMode ? Color.black.opacity(0.5) : .white.opacity(0.58))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

private struct MemberPinnedRabbiRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isLightMode: Bool {
        colorScheme == .light
    }

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
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.85) : .white)
                    Text("Pinned")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.46, green: 0.68, blue: 1.0))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    isLightMode
                                        ? Color(red: 0.2, green: 0.36, blue: 0.74).opacity(0.12)
                                        : Color(red: 0.2, green: 0.36, blue: 0.74).opacity(0.2)
                                )
                        )
                }
                Text("Typically replies quickly")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isLightMode ? Color.black.opacity(0.58) : .white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isLightMode ? Color.black.opacity(0.36) : .white.opacity(0.42))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct MemberPinnedInboxRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isLightMode: Bool {
        colorScheme == .light
    }

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
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.85) : .white)
                    Text("Pinned")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.46, green: 0.68, blue: 1.0))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    isLightMode
                                        ? Color(red: 0.2, green: 0.36, blue: 0.74).opacity(0.12)
                                        : Color(red: 0.2, green: 0.36, blue: 0.74).opacity(0.2)
                                )
                        )
                }
                Text("Open Ask-Rabbi conversations")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isLightMode ? Color.black.opacity(0.58) : .white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isLightMode ? Color.black.opacity(0.36) : .white.opacity(0.42))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct MemberChatRow: View {
    let entry: MemberChatEntry
    var isDeleting: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var isLightMode: Bool {
        colorScheme == .light
    }

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
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.84) : .white)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(isLightMode ? .black.opacity(0.55) : .white.opacity(0.72))
                    } else if !relativeTime.isEmpty {
                        Text(relativeTime)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(isLightMode ? Color.black.opacity(0.48) : .white.opacity(0.6))
                    }
                }

                Text(entry.email)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(isLightMode ? Color.black.opacity(0.48) : .white.opacity(0.58))
                    .lineLimit(1)

                if let lastMessage = entry.lastMessage, !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.74) : .white.opacity(0.82))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Start a new message")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(isLightMode ? Color.black.opacity(0.44) : .white.opacity(0.52))
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
                        .stroke(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.14), lineWidth: 1)
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

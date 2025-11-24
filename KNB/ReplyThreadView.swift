//
//  ReplyThreadView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct ReplyThreadView: View {
    let post: SocialPost
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    @Environment(\.dismiss) var dismiss
    
    @State private var replies: [SocialPost] = []
    @State private var isLoadingReplies = false
    @State private var replyContent = ""
    @State private var isPostingReply = false
    @FocusState private var isFocused: Bool
    
    private let maxCharacters = 140
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable content area
                ScrollView {
                    VStack(spacing: 0) {
                        // Original post at top
                        PostCard(
                            post: post,
                            currentUserEmail: currentUser?.email,
                            currentUserName: currentUser?.name,
                            firestoreManager: firestoreManager,
                            onReply: {
                                // Auto-focus when reply button is clicked
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isFocused = true
                                }
                            },
                            onDelete: {
                                dismiss()
                            }
                        )
                        .padding()
                        
                        // Replies Header
                        HStack {
                            Text("Replies")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            
                            if post.replyCount > 0 {
                                Text("\(post.replyCount)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        
                        // Replies section
                        if isLoadingReplies {
                            ProgressView()
                                .padding()
                        } else if replies.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                
                                Text("No replies yet")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                Text("Be the first to reply!")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(replies) { reply in
                                    ReplyCard(
                                        reply: reply,
                                        currentUserEmail: currentUser?.email,
                                        firestoreManager: firestoreManager,
                                        onDelete: {
                                            loadReplies()
                                        }
                                    )
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    
                                    Divider()
                                        .padding(.leading, 80)
                                }
                            }
                        }
                    }
                }
                
                // Reply composer always visible at bottom (Twitter-style)
                ReplyComposerView(
                    content: $replyContent,
                    isPosting: $isPostingReply,
                    maxCharacters: maxCharacters,
                    shouldFocus: isFocused,
                    onPost: handlePostReply,
                    onCancel: {
                        replyContent = ""
                        isFocused = false
                        dismiss()
                    }
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Replies")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadReplies()
                // Auto-focus reply field when thread opens
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
            .refreshable {
                loadReplies()
            }
        }
    }
    
    private func loadReplies() {
        isLoadingReplies = true
        
        Task {
            let fetchedReplies = await firestoreManager.fetchReplies(for: post.id)
            
            await MainActor.run {
                replies = fetchedReplies
                isLoadingReplies = false
                // Refresh focus after loading replies
                if !replies.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
            }
        }
    }
    
    private func handlePostReply() {
        guard let user = currentUser else { return }
        guard !replyContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard replyContent.count <= maxCharacters else { return }
        
        isPostingReply = true
        
        Task {
            let success = await firestoreManager.createReply(
                parentPostId: post.id,
                content: replyContent,
                author: user
            )
            
            await MainActor.run {
                isPostingReply = false
                if success {
                    replyContent = ""
                    loadReplies()
                    // Re-focus after posting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isFocused = true
                    }
                }
            }
        }
    }
}

// MARK: - Reply Card
struct ReplyCard: View {
    let reply: SocialPost
    let currentUserEmail: String?
    @ObservedObject var firestoreManager: FirestoreManager
    var onDelete: () -> Void
    
    @State private var authorDisplayName: String = ""
    private let userCache = UserCacheManager.shared
    
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var heartScale: CGFloat = 1.0
    @State private var showDeleteConfirmation = false
    
    init(reply: SocialPost, currentUserEmail: String?, firestoreManager: FirestoreManager, onDelete: @escaping () -> Void) {
        self.reply = reply
        self.currentUserEmail = currentUserEmail
        self.firestoreManager = firestoreManager
        self.onDelete = onDelete
        _isLiked = State(initialValue: reply.isLikedBy(currentUserEmail ?? ""))
        _likeCount = State(initialValue: reply.likeCount)
    }
    
    var isOwnReply: Bool {
        currentUserEmail == reply.authorEmail
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: reply.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Thread line - Enhanced design
            VStack(spacing: 0) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.secondary.opacity(0.2),
                                Color.secondary.opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
            }
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.88, green: 0.93, blue: 0.98),
                                        Color(red: 0.90, green: 0.94, blue: 0.99)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.5, blue: 0.92),
                                        Color(red: 0.3, green: 0.55, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(authorDisplayName.isEmpty ? "Loading..." : authorDisplayName)
                                .font(.system(size: 15, weight: .semibold))
                            
                            // Verified badge for admin replies
                            if firestoreManager.adminEmails.contains(reply.authorEmail) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.84, blue: 0.0), // Gold
                                                Color(red: 1.0, green: 0.65, blue: 0.0)  // Darker gold
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            Text(relativeTime)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isOwnReply {
                        Menu {
                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(6)
                        }
                    }
                }
                
                // Reply content
                Text(reply.content)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Like button
                Button(action: handleLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundStyle(isLiked ? .red : .secondary)
                            .scaleEffect(heartScale)
                        
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isLiked ? .red : .secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Delete Reply", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    _ = await firestoreManager.deleteSocialPost(postId: reply.id)
                    onDelete()
                }
            }
        } message: {
            Text("Are you sure you want to delete this reply?")
        }
        .onChange(of: reply.likes) { _, newLikes in
            isLiked = newLikes.contains(currentUserEmail ?? "")
            likeCount = reply.likeCount
        }
        .onChange(of: reply.authorName) { _, newName in
            authorDisplayName = newName
            userCache.cacheName(newName, for: reply.authorEmail)
        }
        .onAppear {
            loadAuthorName()
        }
    }
    
    private func loadAuthorName() {
        // 1. If current user, use current name
        if let currentUserEmail = currentUserEmail, 
           currentUserEmail == reply.authorEmail {
            // Ideally pass currentUserName, but for now rely on reply.authorName if it matches
            // or fetch if needed.
        }
        
        // 2. If reply has a name, use it (Source of Truth)
        if !reply.authorName.isEmpty {
            authorDisplayName = reply.authorName
            // Update cache just in case
            userCache.cacheName(reply.authorName, for: reply.authorEmail)
            return
        }
        
        // 3. Check cache (Fallback)
        if let cachedName = userCache.getCachedName(for: reply.authorEmail) {
            authorDisplayName = cachedName
            return
        }
        
        // 4. Fetch from Firestore
        Task {
            if let userData = await firestoreManager.fetchUserData(email: reply.authorEmail) {
                await MainActor.run {
                    authorDisplayName = userData.name
                    userCache.cacheName(userData.name, for: reply.authorEmail)
                }
            }
        }
    }
    
    private func handleLike() {
        guard let userEmail = currentUserEmail else { return }
        
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += wasLiked ? -1 : 1
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            heartScale = 1.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                heartScale = 1.0
            }
        }
        
        Task {
            let success = await firestoreManager.toggleLike(
                postId: reply.id,
                userEmail: userEmail
            )
            
            if !success {
                await MainActor.run {
                    isLiked = wasLiked
                    likeCount = reply.likeCount
                }
            }
        }
    }
}

// MARK: - Reply Composer
struct ReplyComposerView: View {
    @Binding var content: String
    @Binding var isPosting: Bool
    let maxCharacters: Int
    let shouldFocus: Bool
    var onPost: () -> Void
    var onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.count <= maxCharacters &&
        !isPosting
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(content.count)/\(maxCharacters)")
                    .font(.system(size: 13))
                    .foregroundStyle(
                        (maxCharacters - content.count) < 20 ?
                        ((maxCharacters - content.count) < 0 ? .red : .orange) :
                        .secondary
                    )
                
                Button(action: onPost) {
                    if isPosting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Reply")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    canPost ?
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.5, blue: 0.92),
                            Color(red: 0.3, green: 0.55, blue: 0.96)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [.gray.opacity(0.5), .gray.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .disabled(!canPost)
            }
            
            TextField("Write a reply...", text: $content, axis: .vertical)
                .font(.system(size: 16))
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .focused($isFocused)
                .lineLimit(3...6)
        }
        .padding()
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
        .onChange(of: shouldFocus) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .onAppear {
            if shouldFocus {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isFocused = true
                }
            }
        }
    }
}


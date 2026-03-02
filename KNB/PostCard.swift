//
//  PostCard.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct PostCard: View {
    let post: SocialPost
    let currentUserEmail: String?
    let currentUserName: String?
    @ObservedObject var firestoreManager: FirestoreManager
    var allowsReply: Bool = true
    var allowsLike: Bool = true
    var onReply: () -> Void
    var onDelete: () -> Void
    var onEdit: (() -> Void)?
    
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var heartScale: CGFloat = 1.0
    @State private var showDeleteConfirmation = false
    @State private var authorDisplayName: String = ""
    @Environment(\.colorScheme) private var colorScheme
    private let userCache = UserCacheManager.shared
    
    init(
        post: SocialPost,
        currentUserEmail: String?,
        currentUserName: String? = nil,
        firestoreManager: FirestoreManager,
        allowsReply: Bool = true,
        allowsLike: Bool = true,
        onReply: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onEdit: (() -> Void)? = nil
    ) {
        self.post = post
        self.currentUserEmail = currentUserEmail
        self.currentUserName = currentUserName
        self.firestoreManager = firestoreManager
        self.allowsReply = allowsReply
        self.allowsLike = allowsLike
        self.onReply = onReply
        self.onDelete = onDelete
        self.onEdit = onEdit
        _isLiked = State(initialValue: post.isLikedBy(currentUserEmail ?? ""))
        _likeCount = State(initialValue: post.likeCount)
    }
    
    var isOwnPost: Bool {
        currentUserEmail == post.authorEmail
    }

    private var isLightMode: Bool {
        colorScheme == .light
    }

    private var authorNameColor: Color {
        isLightMode
            ? Color(red: 0.84, green: 0.34, blue: 0.60)
            : Color(red: 1.0, green: 0.47, blue: 0.71)
    }

    private var channelLabelColor: Color {
        isLightMode ? Color.black.opacity(0.48) : Color.white.opacity(0.62)
    }

    private var menuIconColor: Color {
        isLightMode ? Color.black.opacity(0.58) : Color.white.opacity(0.7)
    }

    private var contentTextColor: Color {
        isLightMode ? Color.black.opacity(0.86) : Color.white.opacity(0.96)
    }

    private var metaTextColor: Color {
        isLightMode ? Color.black.opacity(0.48) : Color.white.opacity(0.68)
    }

    private var mutedMetaTextColor: Color {
        isLightMode ? Color.black.opacity(0.38) : Color.white.opacity(0.56)
    }

    private var actionTextColor: Color {
        isLightMode ? Color.black.opacity(0.62) : Color.white.opacity(0.72)
    }

    private var actionDisabledColor: Color {
        isLightMode ? Color.black.opacity(0.24) : Color.white.opacity(0.34)
    }

    private var activeLikeColor: Color {
        Color(red: 0.46, green: 0.90, blue: 0.68)
    }

    private var cardFillGradient: LinearGradient {
        if isLightMode {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    Color(red: 0.94, green: 0.96, blue: 1.0).opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.19, green: 0.20, blue: 0.23),
                Color(red: 0.12, green: 0.13, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardStrokeColor: Color {
        isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.09)
    }

    private var cardShadowColor: Color {
        Color.black.opacity(isLightMode ? 0.10 : 0.22)
    }

    private var isAdminAuthor: Bool {
        let normalizedAuthor = post.authorEmail.lowercased()
        return firestoreManager.adminEmails.contains { $0.lowercased() == normalizedAuthor }
    }

    private var authorChannelLabel: String {
        let trimmed = post.authorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@"), atIndex > trimmed.startIndex else {
            return trimmed.isEmpty ? "updates" : trimmed
        }
        return String(trimmed[..<atIndex])
    }

    private var postTimeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = Calendar.current.isDateInToday(post.timestamp) ? "h:mm a" : "MMM d, h:mm a"
        return formatter.string(from: post.timestamp)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(authorDisplayName.isEmpty ? "Loading..." : authorDisplayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(authorNameColor)

                    if isAdminAuthor {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.41, green: 0.89, blue: 0.67))
                    }

                    Spacer(minLength: 6)

                    Text(authorChannelLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(channelLabelColor)
                        .lineLimit(1)

                    if isOwnPost || firestoreManager.currentUser?.isAdmin == true {
                        Menu {
                            if isOwnPost {
                                Button(action: {
                                    onEdit?()
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }

                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(menuIconColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        }
                    }
                }

                if !post.content.isEmpty {
                    Text(post.content)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(contentTextColor)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !post.mediaItems.isEmpty {
                    SocialPostMediaGalleryView(mediaItems: post.mediaItems, maxHeight: 560)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 4) {
                                if post.isEdited {
                                    Text("Edited")
                                }
                                Text(postTimeLabel)
                            }
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45), in: Capsule())
                            .padding(8)
                        }
                } else {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        if post.isEdited {
                            Text("Edited")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(mutedMetaTextColor)
                        }
                        Text(postTimeLabel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(metaTextColor)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardFillGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStrokeColor, lineWidth: 1)
            )
            .shadow(color: cardShadowColor, radius: 12, x: 0, y: 7)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                guard allowsReply else { return }
                onReply()
            }

            HStack(spacing: 8) {
                if allowsReply {
                    Button(action: onReply) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.system(size: 13, weight: .semibold))
                            if post.replyCount > 0 {
                                Text("\(post.replyCount)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(actionTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                Button(action: handleLike) {
                    HStack(spacing: 5) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                allowsLike
                                ? (isLiked ? activeLikeColor : actionTextColor)
                                : actionDisabledColor
                            )
                            .scaleEffect(heartScale)

                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    allowsLike
                                    ? (isLiked ? activeLikeColor : actionTextColor)
                                    : actionDisabledColor
                                )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .disabled(!allowsLike)
            }
            .padding(.horizontal, 4)
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .onAppear {
            loadAuthorName()
        }
        .onChange(of: post.likes) { _, newLikes in
            isLiked = newLikes.contains(currentUserEmail ?? "")
            likeCount = post.likeCount
        }
        .onChange(of: post.likeCount) { _, newCount in
            likeCount = newCount
        }
        .onChange(of: post.authorName) { _, newName in
            authorDisplayName = newName
            userCache.cacheName(newName, for: post.authorEmail)
        }
    }
    
    private func handleLike() {
        guard allowsLike, let userEmail = currentUserEmail else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Optimistic update
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += wasLiked ? -1 : 1
        
        // Animate heart
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            heartScale = 1.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                heartScale = 1.0
            }
        }
        
        // Update in Firestore
        Task {

            let success = await firestoreManager.toggleLike(
                postId: post.id,
                userEmail: userEmail
            )
            
            if !success {
                // Revert optimistic update on failure
                await MainActor.run {
                    isLiked = wasLiked
                    likeCount = post.likeCount
                }
            }
        }
    }
    
    private func loadAuthorName() {
        // 1. If current user, use current name
        if post.authorEmail == currentUserEmail, let currentName = currentUserName {
            authorDisplayName = currentName
            userCache.cacheName(currentName, for: post.authorEmail)
            return
        }
        
        // 2. If post has a name, use it (Source of Truth)
        if !post.authorName.isEmpty {
            authorDisplayName = post.authorName
            // Update cache just in case
            userCache.cacheName(post.authorName, for: post.authorEmail)
            return
        }
        
        // 3. Check cache (Fallback for legacy posts with no name)
        if let cachedName = userCache.getCachedName(for: post.authorEmail) {
            authorDisplayName = cachedName
            return
        }
        
        // 4. Fetch from Firestore (Last resort)
        Task {
            if let userData = await firestoreManager.fetchUser(email: post.authorEmail) {
                await MainActor.run {
                    authorDisplayName = userData.name
                    userCache.cacheName(userData.name, for: post.authorEmail)
                }
            } else {
                // Fallback if user not found
                await MainActor.run {
                    authorDisplayName = "Unknown User"
                }
            }
        }
    }
}

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
    @ObservedObject var firestoreManager: FirestoreManager
    var onReply: () -> Void
    var onDelete: () -> Void
    
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var heartScale: CGFloat = 1.0
    @State private var showDeleteConfirmation = false
    
    init(post: SocialPost, currentUserEmail: String?, firestoreManager: FirestoreManager, onReply: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.post = post
        self.currentUserEmail = currentUserEmail
        self.firestoreManager = firestoreManager
        self.onReply = onReply
        self.onDelete = onDelete
        _isLiked = State(initialValue: post.isLikedBy(currentUserEmail ?? ""))
        _likeCount = State(initialValue: post.likeCount)
    }
    
    var isOwnPost: Bool {
        currentUserEmail == post.authorEmail
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: post.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with author and menu
            HStack(alignment: .top, spacing: 10) {
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
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
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
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(post.authorName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text("·")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                        
                        Text(relativeTime)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Post content - Directly below username for fluid flow
                    Text(post.content)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Three-dot menu (only for own posts)
                if isOwnPost {
                    Menu {
                        Button(role: .destructive, action: {
                            showDeleteConfirmation = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .padding(6)
                    }
                }
            }
            
            // Action buttons - Better spacing
            HStack(spacing: 0) {
                // Reply button
                Button(action: onReply) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 15, weight: .medium))
                        if post.replyCount > 0 {
                            Text("\(post.replyCount)")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Like button with animation
                Button(action: handleLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isLiked ? .red : .secondary.opacity(0.8))
                            .scaleEffect(heartScale)
                        
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isLiked ? .red : .secondary.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 58)
            .padding(.top, 6)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray6), lineWidth: 0.5)
        )
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .onChange(of: post.likes) { _, newLikes in
            isLiked = newLikes.contains(currentUserEmail ?? "")
            likeCount = post.likeCount
        }
        .onChange(of: post.likeCount) { _, newCount in
            likeCount = newCount
        }
    }
    
    private func handleLike() {
        guard let userEmail = currentUserEmail else { return }
        
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
}


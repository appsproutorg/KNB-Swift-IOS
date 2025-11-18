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
    var onReply: () -> Void
    var onDelete: () -> Void
    var onEdit: (() -> Void)?
    
    @State private var isLiked: Bool
    @State private var likeCount: Int
    @State private var heartScale: CGFloat = 1.0
    @State private var showDeleteConfirmation = false
    @State private var isPressed = false
    @State private var avatarScale: CGFloat = 1.0
    
    init(post: SocialPost, currentUserEmail: String?, currentUserName: String? = nil, firestoreManager: FirestoreManager, onReply: @escaping () -> Void, onDelete: @escaping () -> Void, onEdit: (() -> Void)? = nil) {
        self.post = post
        self.currentUserEmail = currentUserEmail
        self.currentUserName = currentUserName
        self.firestoreManager = firestoreManager
        self.onReply = onReply
        self.onDelete = onDelete
        self.onEdit = onEdit
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
            HStack(alignment: .top, spacing: 12) {
                // Avatar with bubbly effect
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.2),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 58, height: 58)
                        .blur(radius: 8)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.88, green: 0.93, blue: 0.98),
                                    Color(red: 0.92, green: 0.95, blue: 0.99)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3),
                                            Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.5, blue: 0.92),
                                    Color(red: 0.35, green: 0.6, blue: 0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(avatarScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        avatarScale = 1.05
                    }
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
                        
                        if post.isEdited {
                            Text("·")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                            Text("Edited")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
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
                        Button(action: {
                            // Edit action will be handled by parent
                            onEdit?()
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
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
            
            // Action buttons - Bubbly design
            HStack(spacing: 12) {
                // Reply button with bubble effect
                Button(action: onReply) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right.fill")
                            .font(.system(size: 15, weight: .semibold))
                        if post.replyCount > 0 {
                            Text("\(post.replyCount)")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.6, blue: 1.0),
                                Color(red: 0.5, green: 0.7, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Like button with animated bubble
                Button(action: handleLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isLiked ? 
                                LinearGradient(
                                    colors: [.red, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.secondary.opacity(0.6), .secondary.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .scaleEffect(heartScale)
                        
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isLiked ? .red : .secondary.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isLiked ? Color.red.opacity(0.1) : Color.secondary.opacity(0.05))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isLiked ? Color.red.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 62)
            .padding(.top, 10)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.15),
                            Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
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
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: isLiked ? .light : .medium)
        impactFeedback.impactOccurred()
        
        // Optimistic update
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += wasLiked ? -1 : 1
        
        // Explosive heart animation when liking
        if !wasLiked {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                heartScale = 1.4
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    heartScale = 0.9
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    heartScale = 1.0
                }
            }
        } else {
            // Subtle shrink animation when unliking
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                heartScale = 0.8
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    heartScale = 1.0
                }
            }
        }
        
        // Update in Firestore
        Task {
            // Get user name for notification
            let userName = currentUserName ?? "Someone"
            let success = await firestoreManager.toggleLike(
                postId: post.id,
                userEmail: userEmail,
                userName: userName
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



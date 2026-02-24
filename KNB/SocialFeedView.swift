//
//  SocialFeedView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct SocialFeedView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    @EnvironmentObject var navigationManager: NavigationManager
    
    @State private var sortOption: FirestoreManager.SocialPostSortOption = .newest
    @State private var showPostComposer = false
    @State private var postToEdit: SocialPost?
    @State private var selectedPost: SocialPost?
    @State private var showReplyThread = false
    @State private var showRabbiChat = false
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Sort toggle - Glass Switch Design
                    GlassSwitchView(
                        selectedOption: $sortOption,
                        onSelectionChange: { newOption in
                            firestoreManager.startListeningToSocialPosts(sortBy: newOption)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                    
                    // Feed content
                    if firestoreManager.socialPosts.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            
                            Text("No posts yet")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary)
                            
                            Text("Be the first to share something with the community!")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                showPostComposer = true
                            }) {
                                Text("Create First Post")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.25, green: 0.5, blue: 0.92),
                                                Color(red: 0.3, green: 0.55, blue: 0.96)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(20)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Last updated timestamp
                        if let lastUpdated = firestoreManager.lastUpdated {
                            HStack {
                                Spacer()
                                Text("Updated \(timeAgoString(from: lastUpdated))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                            }
                        }
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(firestoreManager.socialPosts) { post in
                                        PostCard(
                                            post: post,
                                            currentUserEmail: currentUser?.email,
                                            currentUserName: currentUser?.name,
                                            firestoreManager: firestoreManager,
                                            onReply: {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    selectedPost = post
                                                    showReplyThread = true
                                                }
                                            },
                                            onDelete: {
                                                Task {
                                                    await firestoreManager.deleteSocialPost(postId: post.id)
                                                }
                                            },
                                            onEdit: {
                                                postToEdit = post
                                                showPostComposer = true
                                            }
                                        )
                                        .id(post.id) // Important for scrolling
                                        .padding(.horizontal)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity.combined(with: .move(edge: .bottom))
                                        ))
                                    }
                                }
                                .padding(.vertical)
                            }
                            .refreshable {
                                await firestoreManager.fetchSocialPosts(sortBy: sortOption)
                            }
                            .onChange(of: navigationManager.navigateToPostId) { _, postId in
                                if let postId = postId {
                                    // Find the post
                                    if let post = firestoreManager.socialPosts.first(where: { $0.id == postId }) {
                                        withAnimation {
                                            proxy.scrollTo(postId, anchor: .top)
                                            selectedPost = post
                                            showReplyThread = true
                                        }
                                        // Reset navigation state
                                        navigationManager.navigateToPostId = nil
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Floating action buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 12) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showPostComposer = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Post")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.25, green: 0.5, blue: 0.92),
                                            Color(red: 0.3, green: 0.55, blue: 0.96)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.4), radius: 15, x: 0, y: 8)
                            }

                            RabbiChatFloatingButton {
                                showRabbiChat = true
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Social")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.5, blue: 0.92),
                                        Color(red: 0.3, green: 0.55, blue: 0.96)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Community Feed")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showPostComposer) {
                PostComposerView(
                    firestoreManager: firestoreManager,
                    currentUser: $currentUser,
                    postToEdit: postToEdit
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemBackground))
                .onDisappear {
                    postToEdit = nil
                }
            }
            .sheet(isPresented: $showReplyThread) {
                if let post = selectedPost {
                    ReplyThreadView(
                        post: post,
                        firestoreManager: firestoreManager,
                        currentUser: $currentUser
                    )
                }
            }
            .fullScreenCover(isPresented: $showRabbiChat) {
                if let currentUser {
                    if firestoreManager.isRabbiAccount(email: currentUser.email) {
                        RabbiInboxView(
                            firestoreManager: firestoreManager,
                            currentUser: currentUser
                        )
                    } else {
                        RabbiChatView(
                            firestoreManager: firestoreManager,
                            currentUser: currentUser,
                            threadOwnerEmail: currentUser.email,
                            threadDisplayName: nil
                        )
                    }
                } else {
                    NavigationStack {
                        ZStack {
                            Color(.systemGroupedBackground).ignoresSafeArea()
                            Text("Please sign in to chat with Rabbi.")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") {
                                    showRabbiChat = false
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                firestoreManager.startListeningToSocialPosts(sortBy: sortOption)
                Task {
                    await firestoreManager.fetchAdmins()
                }
            }
            .onDisappear {
                firestoreManager.stopListeningToSocialPosts()
            }
        }
    }
}

private struct RabbiChatFloatingButton: View {
    let onTap: () -> Void

    @State private var bubbleScale: CGFloat = 1
    @State private var bubbleStretchX: CGFloat = 1
    @State private var bubbleStretchY: CGFloat = 1
    @State private var iconScale: CGFloat = 1
    @State private var iconOffsetY: CGFloat = 0
    @State private var bubbleRotation: Double = 0
    @State private var rippleScale: CGFloat = 0.2
    @State private var rippleOpacity: Double = 0
    @State private var shineOpacity: Double = 0.34
    @State private var idleBreath = false
    @State private var ambientGlow: Double = 0.18
    @State private var sheenOffset: CGFloat = -46
    @State private var isAnimatingTap = false

    var body: some View {
        Button {
            guard !isAnimatingTap else { return }
            isAnimatingTap = true

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // 1) Squish in quickly
            withAnimation(.easeIn(duration: 0.08)) {
                bubbleScale = 0.84
                bubbleStretchX = 1.14
                bubbleStretchY = 0.82
                iconScale = 0.76
                iconOffsetY = 3
                bubbleRotation = -10
                shineOpacity = 0.5
                rippleScale = 0.42
                rippleOpacity = 0.12
            }

            // 2) Blob launch + ripple
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 10).delay(0.08)) {
                bubbleScale = 1.2
                bubbleStretchX = 0.86
                bubbleStretchY = 1.18
                iconScale = 1.15
                iconOffsetY = -3
                bubbleRotation = 8
                rippleScale = 2.6
                rippleOpacity = 0.4
                shineOpacity = 0.64
            }

            // 3) Rebound
            withAnimation(.spring(response: 0.28, dampingFraction: 0.58).delay(0.2)) {
                bubbleScale = 0.98
                bubbleStretchX = 1.05
                bubbleStretchY = 0.95
                iconScale = 0.97
                iconOffsetY = 1
                bubbleRotation = -4
            }

            // 4) Settle
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86).delay(0.31)) {
                bubbleScale = 1.0
                bubbleStretchX = 1.0
                bubbleStretchY = 1.0
                iconScale = 1.0
                iconOffsetY = 0
                bubbleRotation = 0
                shineOpacity = 0.34
            }

            withAnimation(.easeOut(duration: 0.45).delay(0.17)) {
                rippleOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onTap()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                isAnimatingTap = false
                rippleScale = 0.2
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.28))
                    .frame(width: 68, height: 68)
                    .blur(radius: 8)
                    .scaleEffect(idleBreath ? 1.08 : 0.94)
                    .opacity(ambientGlow)

                Circle()
                    .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.35))
                    .frame(width: 58, height: 58)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.blue.opacity(0.28), radius: 12, x: 0, y: 6)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(shineOpacity), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)

                Circle()
                    .fill(Color.clear)
                    .frame(width: 58, height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color.white.opacity(0.38), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 20, height: 78)
                            .rotationEffect(.degrees(28))
                            .offset(x: sheenOffset)
                    )
                    .mask(Circle().frame(width: 58, height: 58))
                    .opacity(isAnimatingTap ? 0.72 : 0.44)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.78, green: 0.9, blue: 1.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(iconScale)
                    .offset(y: iconOffsetY)
            }
            .scaleEffect(bubbleScale * (isAnimatingTap ? 1 : (idleBreath ? 1.03 : 0.98)))
            .scaleEffect(x: bubbleStretchX, y: bubbleStretchY)
            .rotationEffect(.degrees(bubbleRotation))
            .offset(y: isAnimatingTap ? 0 : (idleBreath ? -1.2 : 1.2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chat with Rabbi")
        .onAppear {
            withAnimation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true)) {
                idleBreath = true
                ambientGlow = 0.3
            }
            withAnimation(.linear(duration: 2.1).repeatForever(autoreverses: false)) {
                sheenOffset = 46
            }
        }
    }
}

// MARK: - Glass Switch View
struct GlassSwitchView: View {
    @Binding var selectedOption: FirestoreManager.SocialPostSortOption
    var onSelectionChange: (FirestoreManager.SocialPostSortOption) -> Void
    
    @Namespace private var animation
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Glass background
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                // Sliding indicator
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.25),
                                Color(red: 0.3, green: 0.55, blue: 0.96).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.5),
                                        Color(red: 0.3, green: 0.55, blue: 0.96).opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .frame(width: geometry.size.width / 2 - 4)
                    .padding(2)
                    .offset(x: selectedOption == .newest ? 0 : geometry.size.width / 2 - 4)
                    .matchedGeometryEffect(id: "selected", in: animation)
                
                // Buttons
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedOption = .newest
                            onSelectionChange(.newest)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Newest")
                                .font(.system(size: 15, weight: selectedOption == .newest ? .bold : .semibold))
                        }
                        .foregroundStyle(
                            selectedOption == .newest ?
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.5, blue: 0.92),
                                    Color(red: 0.3, green: 0.55, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [.secondary.opacity(0.8), .secondary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedOption = .mostLiked
                            onSelectionChange(.mostLiked)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Most Liked")
                                .font(.system(size: 15, weight: selectedOption == .mostLiked ? .bold : .semibold))
                        }
                        .foregroundStyle(
                            selectedOption == .mostLiked ?
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.5, blue: 0.92),
                                    Color(red: 0.3, green: 0.55, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [.secondary.opacity(0.8), .secondary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 48)
    }
}

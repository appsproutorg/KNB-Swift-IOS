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
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Updates")
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

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
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showPostComposer = false
    @State private var postToEdit: SocialPost?
    @State private var selectedPost: SocialPost?
    @State private var showReplyThread = false

    private var isAdminUser: Bool {
        currentUser?.isAdmin == true
    }

    private var normalizedAdminEmails: Set<String> {
        Set(firestoreManager.adminEmails.map { $0.lowercased() })
    }

    private var visiblePosts: [SocialPost] {
        guard !isAdminUser else { return firestoreManager.socialPosts }
        return firestoreManager.socialPosts.filter { normalizedAdminEmails.contains($0.authorEmail.lowercased()) }
    }

    private func canLikePost(_ post: SocialPost) -> Bool {
        isAdminUser || normalizedAdminEmails.contains(post.authorEmail.lowercased())
    }

    private var isLightMode: Bool {
        colorScheme == .light
    }

    private var backgroundGradientColors: [Color] {
        if isLightMode {
            return [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.91, green: 0.95, blue: 0.99)
            ]
        }
        return [
            Color(red: 0.04, green: 0.07, blue: 0.11),
            Color(red: 0.02, green: 0.03, blue: 0.06)
        ]
    }

    private var headerTitleColor: Color {
        isLightMode ? Color.black.opacity(0.86) : Color.white.opacity(0.94)
    }

    private var headerSubtitleColor: Color {
        isLightMode ? Color.black.opacity(0.52) : Color.white.opacity(0.58)
    }

    private var emptyPrimaryTextColor: Color {
        isLightMode ? Color.black.opacity(0.84) : Color.white.opacity(0.92)
    }

    private var emptySecondaryTextColor: Color {
        isLightMode ? Color.black.opacity(0.52) : Color.white.opacity(0.62)
    }

    private var updateChipTextColor: Color {
        isLightMode ? Color.black.opacity(0.62) : Color.white.opacity(0.74)
    }

    private var updateChipFillColor: Color {
        isLightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.08)
    }

    private var updateChipStrokeColor: Color {
        isLightMode ? Color.black.opacity(0.11) : Color.white.opacity(0.12)
    }
    
    private func updateStatusText(from date: Date) -> String {
        let now = Date()
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 15 {
            return "Updated just now"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let clampedDate = min(date, now)
        return "Updated \(formatter.localizedString(for: clampedDate, relativeTo: now))"
    }

    private var topHeader: some View {
        VStack(spacing: 2) {
            Text("Updates")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(headerTitleColor)

            Text("Community Channel")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(headerSubtitleColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: isLightMode
                    ? [
                        Color.white.opacity(0.88),
                        Color.white.opacity(0.64),
                        Color.clear
                    ]
                    : [
                        Color.black.opacity(0.24),
                        Color.black.opacity(0.10),
                        Color.clear
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: isLightMode
                    ? [
                        Color.black.opacity(0.09),
                        Color.black.opacity(0.0)
                    ]
                    : [
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.0)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 8)
        }
    }

    private var feedScrollMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: backgroundGradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(
                            isLightMode
                                ? Color(red: 0.27, green: 0.53, blue: 0.91).opacity(0.14)
                                : Color(red: 0.11, green: 0.36, blue: 0.62).opacity(0.22)
                        )
                        .frame(width: 320, height: 320)
                        .blur(radius: 8)
                        .offset(x: -70, y: -120)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            isLightMode
                                ? Color(red: 0.13, green: 0.62, blue: 0.77).opacity(0.12)
                                : Color(red: 0.06, green: 0.24, blue: 0.43).opacity(0.20)
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 10)
                        .offset(x: 90, y: 130)
                }
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topHeader

                    // Feed content
                    if visiblePosts.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundStyle(emptySecondaryTextColor)
                            
                            Text("No posts yet")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(emptyPrimaryTextColor)
                            
                            Text(isAdminUser ? "Be the first to share something with the community!" : "Admins will post updates here.")
                                .font(.system(size: 16))
                                .foregroundStyle(emptySecondaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            if isAdminUser {
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
                                                    Color(red: 0.12, green: 0.67, blue: 0.42),
                                                    Color(red: 0.07, green: 0.57, blue: 0.35)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(20)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Last updated timestamp
                        if let lastUpdated = firestoreManager.lastUpdated {
                            HStack {
                                Spacer()
                                Text(updateStatusText(from: lastUpdated))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(updateChipTextColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(updateChipFillColor)
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .stroke(updateChipStrokeColor, lineWidth: 1)
                                            )
                                    )
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 14) {
                                    ForEach(visiblePosts) { post in
                                        PostCard(
                                            post: post,
                                            currentUserEmail: currentUser?.email,
                                            currentUserName: currentUser?.name,
                                            firestoreManager: firestoreManager,
                                            allowsReply: isAdminUser,
                                            allowsLike: canLikePost(post),
                                            onReply: {
                                                guard isAdminUser else { return }
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
                                        .padding(.horizontal, 10)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity.combined(with: .move(edge: .bottom))
                                        ))
                                    }
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 16)
                            }
                            .mask(feedScrollMask)
                            .refreshable {
                                await firestoreManager.fetchSocialPosts(sortBy: .newest)
                            }
                            .onChange(of: navigationManager.navigateToPostId) { _, postId in
                                if let postId = postId {
                                    // Find the post
                                    if let post = visiblePosts.first(where: { $0.id == postId }) {
                                        withAnimation {
                                            proxy.scrollTo(postId, anchor: .top)
                                            if isAdminUser {
                                                selectedPost = post
                                                showReplyThread = true
                                            }
                                        }
                                        // Reset navigation state
                                        navigationManager.navigateToPostId = nil
                                    } else {
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
                        if isAdminUser {
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
                                            Color(red: 0.12, green: 0.67, blue: 0.42),
                                            Color(red: 0.07, green: 0.57, blue: 0.35)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: Color(red: 0.08, green: 0.53, blue: 0.33).opacity(0.45), radius: 15, x: 0, y: 8)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
                if let post = selectedPost, isAdminUser {
                    ReplyThreadView(
                        post: post,
                        firestoreManager: firestoreManager,
                        currentUser: $currentUser
                    )
                }
            }
            .onAppear {
                firestoreManager.startListeningToSocialPosts(sortBy: .newest)
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

//
//  PostComposerView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct PostComposerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    
    let postToEdit: SocialPost?
    
    @State private var postContent = ""
    @State private var isPosting = false
    @FocusState private var isFocused: Bool
    
    private let maxCharacters = 140
    
    init(firestoreManager: FirestoreManager, currentUser: Binding<User?>, postToEdit: SocialPost? = nil) {
        self.firestoreManager = firestoreManager
        self._currentUser = currentUser
        self.postToEdit = postToEdit
    }
    
    var characterCount: Int {
        postContent.count
    }
    
    var remainingCharacters: Int {
        maxCharacters - characterCount
    }
    
    var canPost: Bool {
        !postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= maxCharacters &&
        !isPosting
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact header with avatar
                HStack(alignment: .top, spacing: 12) {
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
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
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
                    
                    // Text editor - Compact
                    VStack(alignment: .leading, spacing: 12) {
                        // TextEditor with placeholder as background overlay
                        ZStack(alignment: .topLeading) {
                            // Background placeholder that disappears when typing
                            if postContent.isEmpty {
                                Text("What's happening?")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 17))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            
                            // TextEditor - no padding compensation, let it use natural padding
                            TextEditor(text: $postContent)
                                .font(.system(size: 17))
                                .focused($isFocused)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 80, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .background(Color.clear)
                        
                        // Character counter and post button
                        HStack {
                            Spacer()
                            
                            Text("\(characterCount)/\(maxCharacters)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    remainingCharacters < 20 ?
                                    (remainingCharacters < 0 ? .red : .orange) :
                                    .secondary
                                )
                            
                            Button(action: handlePost) {
                                HStack(spacing: 6) {
                                    if isPosting {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Post")
                                            .font(.system(size: 15, weight: .bold))
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
                            }
                            .disabled(!canPost)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle(postToEdit == nil ? "New Post" : "Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                // Pre-fill content if editing
                if let post = postToEdit {
                    postContent = post.content
                }
                // Auto-focus text editor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
    }
    
    private func handlePost() {
        guard let user = currentUser else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        isPosting = true
        
        Task {
            let success: Bool
            if let post = postToEdit {
                // Update existing post
                success = await firestoreManager.updateSocialPost(
                    postId: post.id,
                    content: postContent
                )
            } else {
                // Create new post
                success = await firestoreManager.createSocialPost(
                    content: postContent,
                    author: user
                )
            }
            
            await MainActor.run {
                isPosting = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    PostComposerView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 0))
    )
}


//
//  ChatTabView.swift
//  KNB
//
//  Created by AI Assistant on 2/24/26.
//

import SwiftUI

struct ChatTabView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?

    var body: some View {
        Group {
            if let currentUser {
                MemberChatListView(
                    firestoreManager: firestoreManager,
                    currentUser: currentUser
                )
            } else {
                NavigationStack {
                    ZStack {
                        Color(.systemGroupedBackground).ignoresSafeArea()
                        Text("Please sign in to use chat.")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
            }
        }
    }
}

struct RabbiTabView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?

    private func signedOutPlaceholder(text: String) -> some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                Text(text)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    var body: some View {
        Group {
            if let currentUser {
                if firestoreManager.isRabbiAccount(email: currentUser.email) {
                    RabbiInboxView(
                        firestoreManager: firestoreManager,
                        currentUser: currentUser,
                        showsCloseButton: false
                    )
                } else {
                    RabbiChatView(
                        firestoreManager: firestoreManager,
                        currentUser: currentUser,
                        threadOwnerEmail: currentUser.email,
                        threadDisplayName: nil,
                        showsDismissButton: false
                    )
                }
            } else {
                signedOutPlaceholder(text: "Please sign in to message a rabbi.")
            }
        }
    }
}

#Preview {
    ChatTabView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(
            User(
                name: "Preview User",
                email: "preview@example.com",
                totalPledged: 0,
                isAdmin: false,
                notificationPrefs: NotificationPreferences()
            )
        )
    )
}

#Preview("Rabbi Tab") {
    RabbiTabView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(
            User(
                name: "Preview User",
                email: "preview@example.com",
                totalPledged: 0,
                isAdmin: false,
                notificationPrefs: NotificationPreferences()
            )
        )
    )
}

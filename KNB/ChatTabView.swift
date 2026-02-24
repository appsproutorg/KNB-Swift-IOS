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

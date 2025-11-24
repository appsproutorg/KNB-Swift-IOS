//
//  AdminManagementView.swift
//  KNB
//
//  Created by AI Assistant on 11/24/25.
//

import SwiftUI

struct AdminManagementView: View {
    @EnvironmentObject var firestoreManager: FirestoreManager
    @State private var users: [User] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading users...")
                } else {
                    List {
                        ForEach(filteredUsers, id: \.email) { user in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if user.email.lowercased() == "admin@knb.com" {
                                    Text("Super Admin")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(6)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(8)
                                } else {
                                    Button(action: {
                                        toggleAdminStatus(for: user)
                                    }) {
                                        Text(user.isAdmin ? "Admin" : "Member")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .padding(6)
                                            .frame(width: 70)
                                            .background(user.isAdmin ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .foregroundColor(user.isAdmin ? .blue : .secondary)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search users")
                }
            }
            .navigationTitle("Manage Admins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUsers()
            }
        }
    }
    
    func loadUsers() {
        Task {
            isLoading = true
            users = await firestoreManager.fetchAllUsers()
            isLoading = false
        }
    }
    
    func toggleAdminStatus(for user: User) {
        Task {
            let newStatus = !user.isAdmin
            let success = await firestoreManager.updateUserAdminStatus(email: user.email, isAdmin: newStatus)
            
            if success {
                // Update local list
                if let index = users.firstIndex(where: { $0.email == user.email }) {
                    users[index].isAdmin = newStatus
                }
            }
        }
    }
}

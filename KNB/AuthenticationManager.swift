//
//  AuthenticationManager.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    private var hasCheckedAuth = false
    
    init() {
        // Defer auth check until after Firebase is fully initialized
    }
    
    func checkAuthState() {
        guard !hasCheckedAuth else { return }
        hasCheckedAuth = true
        
        // Check if user is already logged in
        if let firebaseUser = Auth.auth().currentUser {
            loadUserData(from: firebaseUser)
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, name: String) async -> Bool {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            // Create user object
            user = User(
                name: name,
                email: email,
                totalPledged: 0
            )
            
            isAuthenticated = true
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async -> Bool {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            loadUserData(from: authResult.user)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
            isAuthenticated = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper Methods
    private func loadUserData(from firebaseUser: FirebaseAuth.User) {
        user = User(
            name: firebaseUser.displayName ?? "Member",
            email: firebaseUser.email ?? "",
            totalPledged: 0 // TODO: Load from Firestore when you add it
        )
        isAuthenticated = true
    }
}


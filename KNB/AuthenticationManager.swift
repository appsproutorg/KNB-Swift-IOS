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
                totalPledged: 0,
                isAdmin: isAdminEmail(email)
            )
            
            isAuthenticated = true
            errorMessage = nil
            return true
        } catch {
            errorMessage = getSignUpErrorMessage(from: error)
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
            errorMessage = getSignInErrorMessage(from: error)
            return false
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async -> Bool {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = nil
            return true
        } catch {
            errorMessage = getPasswordResetErrorMessage(from: error)
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
        let email = firebaseUser.email ?? ""
        user = User(
            name: firebaseUser.displayName ?? "Member",
            email: email,
            totalPledged: 0, // TODO: Load from Firestore when you add it
            isAdmin: isAdminEmail(email)
        )
        isAuthenticated = true
    }
    
    // Check if email is an admin email
    // TODO: Move this to Firestore for better security and flexibility
    private func isAdminEmail(_ email: String) -> Bool {
        let adminEmails = [
            "appsproutorg@gmail.com", // Add admin emails here
            "admin@knb.com"
        ]
        return adminEmails.contains(email.lowercased())
    }
    
    // MARK: - Error Message Helpers
    private func getSignUpErrorMessage(from error: Error) -> String {
        guard let authError = error as NSError?,
              let errorCode = AuthErrorCode(_bridgedNSError: authError)?.code else {
            return "Unable to create account. Please try again."
        }
        
        switch errorCode {
        case .emailAlreadyInUse:
            return "This email is already registered. Please sign in instead."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return "Unable to create account. Please try again."
        }
    }
    
    private func getSignInErrorMessage(from error: Error) -> String {
        guard let authError = error as NSError?,
              let errorCode = AuthErrorCode(_bridgedNSError: authError)?.code else {
            return "Unable to sign in. Please try again."
        }
        
        switch errorCode {
        case .userNotFound:
            return "No account found with this email. Please sign up first."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .userDisabled:
            return "This account has been disabled. Please contact support."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return "Unable to sign in. Please check your email and password."
        }
    }
    
    private func getPasswordResetErrorMessage(from error: Error) -> String {
        guard let authError = error as NSError?,
              let errorCode = AuthErrorCode(_bridgedNSError: authError)?.code else {
            return "Unable to send password reset email. Please try again."
        }
        
        switch errorCode {
        case .userNotFound:
            return "No account found with this email address."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return "Unable to send password reset email. Please try again."
        }
    }
}


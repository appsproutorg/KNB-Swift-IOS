//
//  AuthenticationManager.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    private var hasCheckedAuth = false
    private var firestoreManager: FirestoreManager?
    
    init() {
        // Defer auth check until after Firebase is fully initialized
    }
    
    func setFirestoreManager(_ manager: FirestoreManager) {
        self.firestoreManager = manager
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
            let newUser = User(
                name: name,
                email: email,
                totalPledged: 0,
                isAdmin: isAdminEmail(email)
            )
            user = newUser
            
            // Sync user to Firestore
            if let firestoreManager = firestoreManager {
                _ = await firestoreManager.createOrUpdateUser(user: newUser)
            }
            
            // Store FCM token if available
            await storeFCMTokenIfAvailable()
            
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
            
            // Store FCM token if available
            await storeFCMTokenIfAvailable()
            
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
        
        // Try to load from cache first for instant UI
        if let cachedUser = loadCachedUser(email: email) {
            user = cachedUser
            isAuthenticated = true
        }
        
        // Then load from Firestore to get latest data
        Task {
            if let firestoreManager = firestoreManager {
                if let firestoreUser = await firestoreManager.fetchUserData(email: email) {
                    // User exists in Firestore, use that data
                    user = firestoreUser
                    // Cache the updated user data
                    cacheUser(user: firestoreUser)
                } else {
                    // User doesn't exist in Firestore yet, create with defaults
                    let newUser = User(
                        name: firebaseUser.displayName ?? "Member",
                        email: email,
                        totalPledged: 0,
                        isAdmin: isAdminEmail(email)
                    )
                    user = newUser
                    // Cache and create user document in Firestore
                    cacheUser(user: newUser)
                    _ = await firestoreManager.createOrUpdateUser(user: newUser)
                }
            } else {
                // FirestoreManager not set yet, use defaults
                let defaultUser = User(
                    name: firebaseUser.displayName ?? "Member",
                    email: email,
                    totalPledged: 0,
                    isAdmin: isAdminEmail(email)
                )
                user = defaultUser
                cacheUser(user: defaultUser)
            }
            isAuthenticated = true
        }
    }
    
    // Cache user profile data
    private func cacheUser(user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "cached_user_\(user.email)")
        }
    }
    
    // Load cached user profile data
    private func loadCachedUser(email: String) -> User? {
        guard let data = UserDefaults.standard.data(forKey: "cached_user_\(email)"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    // Check if email is an admin email
    // TODO: Move this to Firestore for better security and flexibility
    // MARK: - FCM Token Management
    private func storeFCMTokenIfAvailable() async {
        if let fcmToken = UserDefaults.standard.string(forKey: "fcmToken"),
           let userEmail = user?.email {
            let db = Firestore.firestore()
            do {
                try await db.collection("users").document(userEmail).setData([
                    "fcmToken": fcmToken,
                    "fcmTokenUpdatedAt": Timestamp(date: Date())
                ], merge: true)
                print("✅ Stored FCM token for user: \(userEmail)")
            } catch {
                print("❌ Error storing FCM token: \(error.localizedDescription)")
            }
        }
    }
    
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


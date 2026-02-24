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
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    private var hasCheckedAuth = false
    private var firestoreManager: FirestoreManager?
    private var loadUserTask: Task<Void, Never>?
    
    init() {
        // Defer auth check until after Firebase is fully initialized
    }
    
    func setFirestoreManager(_ manager: FirestoreManager) {
        self.firestoreManager = manager
    }
    
    func checkAuthState() async {
        guard !hasCheckedAuth else { return }
        hasCheckedAuth = true
        
        // Check if user is already logged in
        if let firebaseUser = Auth.auth().currentUser {
            await loadUserData(from: firebaseUser)
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
            await loadUserData(from: authResult.user)
            
            // Store FCM token if available
            await storeFCMTokenIfAvailable()
            
            errorMessage = nil
            return true
        } catch {
            errorMessage = getSignInErrorMessage(from: error)
            return false
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle(presenting viewController: UIViewController) async -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In is not configured correctly."
            return false
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Could not get Google ID token."
                return false
            }

            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let authResult = try await Auth.auth().signIn(with: credential)

            await loadUserData(from: authResult.user)
            await storeFCMTokenIfAvailable()

            errorMessage = nil
            return true
        } catch {
            errorMessage = getGoogleSignInErrorMessage(from: error)
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
    func signOut() async {
        loadUserTask?.cancel()
        loadUserTask = nil

        let signedInEmail = user?.email ?? Auth.auth().currentUser?.email
        await removeStoredFCMTokenIfAvailable(for: signedInEmail)

        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        firestoreManager?.stopListening()
        firestoreManager?.currentUser = nil

        user = nil
        isAuthenticated = false
        errorMessage = nil
    }
    
    // MARK: - Helper Methods
    private func loadUserData(from firebaseUser: FirebaseAuth.User) async {
        loadUserTask?.cancel()

        let email = firebaseUser.email ?? ""
        
        // Try to load from cache first for instant UI
        if let cachedUser = loadCachedUser(email: email) {
            user = cachedUser
            isAuthenticated = true
        }
        
        // Then load from Firestore to get latest data
        loadUserTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard !Task.isCancelled else { return }

            if let firestoreManager = firestoreManager {
                if let firestoreUser = await firestoreManager.fetchUserData(email: email) {
                    guard !Task.isCancelled else { return }
                    guard Auth.auth().currentUser?.email == email else { return }
                    // User exists in Firestore, use that data
                    user = firestoreUser
                    // Cache the updated user data
                    cacheUser(user: firestoreUser)
                    await firestoreManager.ensureChatDirectoryEntry(for: firestoreUser)

                    if firestoreUser.isAdmin {
                        await firestoreManager.backfillChatDirectoryFromUsersIfAdmin()
                    }
                } else {
                    // User doesn't exist in Firestore yet, create with defaults
                    let newUser = User(
                        name: firebaseUser.displayName ?? "Member",
                        email: email,
                        totalPledged: 0,
                        isAdmin: isAdminEmail(email)
                    )
                    guard !Task.isCancelled else { return }
                    guard Auth.auth().currentUser?.email == email else { return }
                    user = newUser
                    // Cache and create user document in Firestore
                    cacheUser(user: newUser)
                    _ = await firestoreManager.createOrUpdateUser(user: newUser)

                    if newUser.isAdmin {
                        await firestoreManager.backfillChatDirectoryFromUsersIfAdmin()
                    }
                }
            } else {
                // FirestoreManager not set yet, use defaults
                let defaultUser = User(
                    name: firebaseUser.displayName ?? "Member",
                    email: email,
                    totalPledged: 0,
                    isAdmin: isAdminEmail(email)
                )
                guard !Task.isCancelled else { return }
                guard Auth.auth().currentUser?.email == email else { return }
                user = defaultUser
                cacheUser(user: defaultUser)
            }
            isAuthenticated = true
        }

        await loadUserTask?.value
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
                let tokenData: [String: Any] = [
                    "platform": "ios",
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                try await db.collection("users").document(userEmail).setData([
                    "fcmTokens": [
                        fcmToken: tokenData
                    ],
                    "fcmToken": FieldValue.delete(),
                    "fcmTokenUpdatedAt": FieldValue.delete()
                ], merge: true)
                print("✅ Stored FCM token for user: \(userEmail)")
            } catch {
                print("❌ Error storing FCM token: \(error.localizedDescription)")
            }
        }
    }

    private func removeStoredFCMTokenIfAvailable(for userEmail: String?) async {
        guard let userEmail, !userEmail.isEmpty else { return }
        guard let fcmToken = UserDefaults.standard.string(forKey: "fcmToken"), !fcmToken.isEmpty else { return }

        do {
            try await Firestore.firestore().collection("users").document(userEmail).updateData([
                FieldPath(["fcmTokens", fcmToken]): FieldValue.delete()
            ])
            print("🧹 Removed FCM token mapping for signed-out user: \(userEmail)")
        } catch {
            print("⚠️ Failed to remove FCM token on sign-out: \(error.localizedDescription)")
        }
    }
    
    private func isAdminEmail(_ email: String) -> Bool {
        return email.lowercased() == "admin@knb.com"
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

    private func getGoogleSignInErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        let isGoogleCancelCode = nsError.domain.contains("GIDSignIn") && nsError.code == -5
        if isGoogleCancelCode {
            return "Google sign in was canceled."
        }

        return "Unable to sign in with Google. Please try again."
    }
}

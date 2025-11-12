//
//  ContentView.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var showSplash = true
    @State private var hasInitialized = false
    
    var body: some View {
        if showSplash {
            SplashScreenView(onComplete: {
                // Check auth state after Firebase is fully initialized
                authManager.checkAuthState()
                withAnimation {
                    showSplash = false
                }
            })
        } else {
            Group {
                if authManager.isAuthenticated {
                    MainTabView(
                        firestoreManager: firestoreManager,
                        currentUser: $authManager.user,
                        authManager: authManager
                    )
                    .onAppear {
                        if !hasInitialized {
                            hasInitialized = true
                            Task {
                                await firestoreManager.initializeHonorsInFirestore()
                                
                                // Fix any malformed dates in Firestore (one-time)
                                print("🔧 Fixing malformed sponsorship dates...")
                                await firestoreManager.fixMalformedDates()
                                
                                // Debug: List all sponsorships to verify
                                print("🔍 Debugging sponsorships in Firestore...")
                                await firestoreManager.debugListAllSponsorships()
                            }
                        }
                        firestoreManager.startListening()
                    }
                    .onDisappear {
                        firestoreManager.stopListening()
                    }
                } else {
                    LoginView(authManager: authManager)
                }
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    ContentView()
}

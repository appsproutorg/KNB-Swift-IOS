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
                    AuctionListView(
                        firestoreManager: firestoreManager,
                        currentUser: $authManager.user,
                        authManager: authManager
                    )
                    .onAppear {
                        if !hasInitialized {
                            hasInitialized = true
                            Task {
                                await firestoreManager.initializeHonorsInFirestore()
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

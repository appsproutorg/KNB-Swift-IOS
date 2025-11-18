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
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var showSplash = true
    @State private var hasInitialized = false
    
    init() {
        // Set FirestoreManager in AuthenticationManager
    }
    
    var body: some View {
        Group {
            if showSplash {
                SplashScreenView(
                    onComplete: {
                        withAnimation {
                            showSplash = false
                        }
                    },
                    preloadData: {
                        // Check auth state first
                        await MainActor.run {
                            authManager.checkAuthState()
                        }
                        
                        // If user is authenticated, preload data
                        if authManager.isAuthenticated {
                            print("✨ Preloading data for authenticated user...")
                            
                            // Preload Firestore data
                            await firestoreManager.initializeHonorsInFirestore()
                            await firestoreManager.fetchKiddushSponsorships()
                            
                            // Preload calendar data (90 days)
                            let hebrewCalendarService = HebrewCalendarService()
                            await hebrewCalendarService.preload90Days()
                            
                            print("✅ Data preloading complete!")
                            
                            hasInitialized = true
                        }
                    }
                )
            } else {
                Group {
                    if authManager.isAuthenticated {
                        ZStack(alignment: .top) {
                            MainTabView(
                                firestoreManager: firestoreManager,
                                currentUser: $authManager.user,
                                authManager: authManager
                            )
                            .environmentObject(appSettings)
                            .environmentObject(networkMonitor)
                            .onAppear {
                                // Start network monitoring
                                networkMonitor.startMonitoring()
                                // Start real-time listeners (data already preloaded)
                                firestoreManager.startListening()
                            }
                            .onDisappear {
                                firestoreManager.stopListening()
                                networkMonitor.stopMonitoring()
                            }
                            
                            // Network status indicator
                            if !networkMonitor.isConnected {
                                NetworkStatusBanner(isConnected: networkMonitor.isConnected)
                                    .transition(.move(edge: .top))
                            }
                        }
                    } else {
                        LoginView(authManager: authManager)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Set FirestoreManager in AuthenticationManager
            authManager.setFirestoreManager(firestoreManager)
        }
    }
}

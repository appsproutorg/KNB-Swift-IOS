//
//  KNBApp.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI
import FirebaseCore


import FirebaseFirestore


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // FirebaseAppCheck is disabled via Info.plist (FirebaseAppCheckEnabled = NO)
        // FirebaseInAppMessaging errors are harmless - the API isn't enabled in Firebase Console
        // but the SDK still tries to initialize it. These warnings won't affect app functionality.
        
        FirebaseApp.configure()
        
        // Configure Firestore settings for better connection handling
        // Note: Firestore IS a cloud database - it needs internet connection to sync data
        // The "backend" message is just informational - the app works offline with cached data
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        // Enable offline persistence with cache settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 40 * 1024 * 1024 as NSNumber) // 40MB cache
        db.settings = settings
        
        return true
    }
}

@main
struct KNBApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appSettings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.colorScheme)
        }
    }
}

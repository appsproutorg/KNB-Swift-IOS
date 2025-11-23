//
//  KNBApp.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
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
        
        // Set up notification delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Error requesting notification permissions: \(error.localizedDescription)")
            } else {
                print("✅ Notification permissions granted: \(granted)")
            }
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // Handle APNs token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Registered for remote notifications")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Handle FCM token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 FCM Registration token: \(String(describing: fcmToken))")
        
        if let token = fcmToken {
            // Store token in UserDefaults for later use
            UserDefaults.standard.set(token, forKey: "fcmToken")
            
            // If user is logged in, store token in Firestore
            if let currentUser = Auth.auth().currentUser {
                Task {
                    await storeFCMToken(token: token, userEmail: currentUser.email ?? "")
                }
            }
        }
    }
    
    // Store FCM token in Firestore
    private func storeFCMToken(token: String, userEmail: String) async {
        let db = Firestore.firestore()
        do {
            try await db.collection("users").document(userEmail).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": Timestamp(date: Date())
            ], merge: true)
            print("✅ Stored FCM token for user: \(userEmail)")
        } catch {
            print("❌ Error storing FCM token: \(error.localizedDescription)")
        }
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 Received notification in foreground: \(userInfo)")
        
        // Show notification even when app is in foreground
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification: \(userInfo)")
        
        // Handle notification tap (e.g., navigate to specific screen)
        // You can add navigation logic here based on notification data
        
        completionHandler()
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

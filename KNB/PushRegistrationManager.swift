//
//  PushRegistrationManager.swift
//  KNB
//
//  Created by AI Assistant on 11/23/25.
//

import Foundation
import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import Combine

class PushRegistrationManager: NSObject, ObservableObject {
    static let shared = PushRegistrationManager()
    
    @Published var isPermissionGranted = false
    
    override private init() {
        super.init()
    }
    
    func requestPermissions() {
        print("📱 Requesting notification permissions...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("📱 Permission result: \(granted ? "GRANTED" : "DENIED")")
            
            if let error = error {
                print("❌ Error requesting notification permissions: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
                if granted {
                    print("📱 Registering for remote notifications...")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    print("⚠️ Notification permissions DENIED - user must enable in Settings")
                }
            }
        }
        
        // Also check current settings
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📱 Current notification authorization status: \(settings.authorizationStatus.rawValue)")
            print("   0=notDetermined, 1=denied, 2=authorized, 3=provisional, 4=ephemeral")
            print("📱 Alert style: \(settings.alertStyle.rawValue) (0=none, 1=banner, 2=alert)")
            print("📱 Alert setting: \(settings.alertSetting.rawValue) (0=notSupported, 1=disabled, 2=enabled)")
        }
    }
    
    func syncFCMToken(for userEmail: String) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let token = token else { return }
            print("FCM Token: \(token)")
            
            // Update token in Firestore
            let db = Firestore.firestore()
            let tokenData: [String: Any] = [
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            db.collection("users").document(userEmail).setData([
                "fcmTokens": [
                    token: tokenData
                ]
            ], merge: true) { error in
                if let error = error {
                    print("Error syncing FCM token: \(error.localizedDescription)")
                } else {
                    print("Successfully synced FCM token for user: \(userEmail)")
                }
            }
        }
    }
    
    // Test function: Schedule a local notification to verify banner display works
    func scheduleLocalTest() {
        let content = UNMutableNotificationContent()
        content.title = "LOCAL Test"
        content.body = "This is a local notification test - should show banner!"
        content.sound = .default
        content.badge = 1
        // iOS 15+ interruption level
        content.interruptionLevel = .active
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling local notification: \(error.localizedDescription)")
            } else {
                print("✅ Local notification scheduled - should appear in 1 second")
            }
        }
    }
    
    // Diagnostic: Check all notification settings in detail
    func printNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📊 ========== NOTIFICATION SETTINGS DIAGNOSTIC ==========")
            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
            switch settings.authorizationStatus {
            case .notDetermined: print("  → Not Determined (user hasn't been asked)")
            case .denied: print("  → DENIED (user rejected or disabled in Settings)")
            case .authorized: print("  → Authorized ✅")
            case .provisional: print("  → Provisional")
            case .ephemeral: print("  → Ephemeral")
            @unknown default: print("  → Unknown")
            }
            
            print("Alert Style: \(settings.alertStyle.rawValue)")
            switch settings.alertStyle {
            case .none: print("  → NONE ❌ (This is the problem! Banners disabled)")
            case .banner: print("  → Banner ✅")
            case .alert: print("  → Alert ✅")
            @unknown default: print("  → Unknown")
            }
            
            print("Alert Setting: \(settings.alertSetting.rawValue)")
            print("Badge Setting: \(settings.badgeSetting.rawValue)")
            print("Sound Setting: \(settings.soundSetting.rawValue)")
            print("Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
            print("Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
            print("Announcement Setting: \(settings.announcementSetting.rawValue)")
            print("Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
            print("Provides App Notification Settings: \(settings.providesAppNotificationSettings)")
            print("Show Previews Setting: \(settings.showPreviewsSetting.rawValue)")
            print("========== END DIAGNOSTIC ==========")
        }
    }
}

extension PushRegistrationManager: UNUserNotificationCenterDelegate {
    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        print("🔔 ========== WILLPRESENT CALLED ==========")
        print("🔔 Title: \(content.title)")
        print("🔔 Body: \(content.body)")
        print("🔔 App State: \(UIApplication.shared.applicationState.rawValue) (0=Active, 1=Inactive, 2=Background)")
        print("🔔 Thread: \(Thread.current.isMainThread ? "Main" : "Background")")
        print("🔔 Notification ID: \(notification.request.identifier)")
        
        // Show banner, sound, badge, and list even when app is in foreground
        // CRITICAL: Dispatch back to main thread for the completion handler
        DispatchQueue.main.async {
            print("🔔 Calling completionHandler with [.banner, .sound, .badge, .list]")
            completionHandler([.banner, .sound, .badge, .list])
            print("🔔 ========== COMPLETION HANDLER CALLED ==========")
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification: \(userInfo)")
        
        // Handle deep linking here if needed
        // NotificationManager or AppState can observe this
        
        completionHandler()
    }
}

extension PushRegistrationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        // Note: Token sync is handled explicitly when user logs in or app starts
        // But we can also trigger a sync here if we have a current user
        if let _ = fcmToken, let userEmail = Auth.auth().currentUser?.email {
            syncFCMToken(for: userEmail)
        }
    }
}

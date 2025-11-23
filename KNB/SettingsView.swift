//
//  SettingsView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @EnvironmentObject var firestoreManager: FirestoreManager
    @Environment(\.dismiss) var dismiss
    
    // App Version
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Appearance Section
                Section {
                    ThemeSelectionRow(selectedTheme: $appSettings.themeMode)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how the app looks on your device.")
                }
                
                // MARK: - Notification Settings
                if let user = firestoreManager.currentUser {
                    Section {
                        NotificationToggleRow(
                            isOn: Binding(
                                get: { user.notificationPrefs?.adminPosts ?? true },
                                set: { newValue in updatePref { $0.adminPosts = newValue } }
                            ),
                            title: "Admin Announcements",
                            icon: "megaphone.fill",
                            color: .red
                        )
                        
                        NotificationToggleRow(
                            isOn: Binding(
                                get: { user.notificationPrefs?.postLikes ?? true },
                                set: { newValue in updatePref { $0.postLikes = newValue } }
                            ),
                            title: "Post Likes",
                            icon: "heart.fill",
                            color: .pink
                        )
                        
                        NotificationToggleRow(
                            isOn: Binding(
                                get: { user.notificationPrefs?.postReplies ?? true },
                                set: { newValue in updatePref { $0.postReplies = newValue } }
                            ),
                            title: "Post Replies",
                            icon: "bubble.left.fill",
                            color: .blue
                        )
                        
                        NotificationToggleRow(
                            isOn: Binding(
                                get: { user.notificationPrefs?.replyLikes ?? true },
                                set: { newValue in updatePref { $0.replyLikes = newValue } }
                            ),
                            title: "Reply Likes",
                            icon: "heart.fill",
                            color: .pink
                        )
                        
                        NotificationToggleRow(
                            isOn: Binding(
                                get: { user.notificationPrefs?.outbid ?? true },
                                set: { newValue in updatePref { $0.outbid = newValue } }
                            ),
                            title: "Outbid Alerts",
                            icon: "gavel.fill",
                            color: .orange
                        )
                    } header: {
                        Text("Notifications")
                    }
                    
                    // MARK: - Debug Section
                    Section {
                        Button {
                            Task {
                                do {
                                    guard let user = Auth.auth().currentUser else { return }
                                    let token = try await user.getIDToken()
                                    
                                    let url = URL(string: "https://us-central1-the-knb-app.cloudfunctions.net/sendTestNotification")!
                                    var request = URLRequest(url: url)
                                    request.httpMethod = "POST"
                                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                                    // Callable functions expect the body to be wrapped in a "data" key
                                    let body: [String: Any] = ["data": [String: Any]()]
                                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                                    
                                    let (_, response) = try await URLSession.shared.data(for: request)
                                    
                                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                                        print("✅ Test notification sent successfully")
                                    } else {
                                        print("❌ Failed to send test notification")
                                    }
                                } catch {
                                    print("❌ Error sending test notification: \(error.localizedDescription)")
                                }
                            }
                        } label: {
                            Label("Send Test Notification", systemImage: "bell.badge.fill")
                                .foregroundStyle(.blue)
                        }
                        
                        Button {
                            PushRegistrationManager.shared.scheduleLocalTest()
                        } label: {
                            Label("Test LOCAL Notification", systemImage: "bell.circle.fill")
                                .foregroundStyle(.green)
                        }
                        
                        Button {
                            PushRegistrationManager.shared.printNotificationSettings()
                        } label: {
                            Label("Check Notification Settings", systemImage: "gear.badge")
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Debug")
                    }
                }
                
                // MARK: - About Section
                Section {
                    SettingsRow(
                        icon: "info.circle.fill",
                        color: .blue,
                        title: "Version",
                        value: "\(appVersion) (\(buildNumber))"
                    )
                    
                    SettingsRow(
                        icon: "c.circle.fill",
                        color: .purple,
                        title: "Copyright",
                        value: "© 2025 KNB"
                    )
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func updatePref(_ modifier: (inout NotificationPreferences) -> Void) {
        guard let user = firestoreManager.currentUser else { return }
        var prefs = user.notificationPrefs ?? NotificationPreferences()
        modifier(&prefs)
        
        // 1. Optimistic Update: Update UI immediately
        var updatedUser = user
        updatedUser.notificationPrefs = prefs
        firestoreManager.currentUser = updatedUser
        
        // 2. Async Update: Sync to Firestore
        Task {
            await firestoreManager.updateNotificationPreferences(prefs: prefs, userEmail: user.email)
        }
    }
}

// MARK: - Helper Components

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    var value: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NotificationToggleRow: View {
    @Binding var isOn: Bool
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Toggle(title, isOn: $isOn)
        }
        .padding(.vertical, 4)
    }
}

struct ThemeSelectionRow: View {
    @Binding var selectedTheme: ThemeMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("App Theme")
                    .font(.system(size: 16, weight: .medium))
            }
            
            Picker("Theme", selection: $selectedTheme) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsView(appSettings: AppSettings())
}

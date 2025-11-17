//
//  SettingsView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appSettings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $appSettings.notificationsEnabled)
                    
                    if appSettings.notificationsEnabled {
                        Toggle("Like Notifications", isOn: $appSettings.likeNotificationsEnabled)
                        Toggle("Reply Notifications", isOn: $appSettings.replyNotificationsEnabled)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(appSettings: AppSettings())
}


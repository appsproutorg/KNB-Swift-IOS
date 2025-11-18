//
//  AppSettings.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import Foundation
import SwiftUI
import Combine

enum ThemeMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class AppSettings: ObservableObject {
    @AppStorage("themeMode") var themeMode: ThemeMode = .system
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("likeNotificationsEnabled") var likeNotificationsEnabled: Bool = true
    @AppStorage("replyNotificationsEnabled") var replyNotificationsEnabled: Bool = true
    
    var colorScheme: ColorScheme? {
        themeMode.colorScheme
    }
}


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

    
    var colorScheme: ColorScheme? {
        themeMode.colorScheme
    }
}


//
//  MainTabView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    @ObservedObject var authManager: AuthenticationManager
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var selectedTab = 0
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    var body: some View {
        TabView(selection: $selectedTab) {
                // Kiddush Tab
                CalendarView(
                    firestoreManager: firestoreManager,
                    currentUser: $currentUser
                )
                .tabItem {
                    Label("Kiddush", systemImage: "calendar")
                }
                .tag(0)
                
                // Social Tab
                SocialFeedView(
                    firestoreManager: firestoreManager,
                    currentUser: $currentUser
                )
                .tabItem {
                    Label("Social", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(1)
                
                // Auction Tab
                AuctionListView(
                    firestoreManager: firestoreManager,
                    currentUser: $currentUser,
                    authManager: authManager
                )
                .tabItem {
                    Label("Auction", systemImage: "book.closed")
                }
                .tag(2)
                
                // Profile Tab
                ProfileTabView(
                    user: $currentUser,
                    authManager: authManager,
                    firestoreManager: firestoreManager
                )
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .tint(.blue)
        .onAppear {
            setupLiquidGlassTabBar()
        }
    }
    
    // MARK: - Liquid Glass Tab Bar Setup
    private func setupLiquidGlassTabBar() {
        // Configure iOS 26 Liquid Glass appearance
        let appearance = UITabBarAppearance()
        
        if reduceTransparency {
            // Use solid background for accessibility
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
        } else {
            // Apply Liquid Glass effect
            appearance.configureWithTransparentBackground()
            
            // Set background with translucent material
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
            
            // Configure shadow for depth
            appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
            appearance.shadowImage = UIImage()
        }
        
        // Style for unselected items
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
        
        // Style for selected items
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.systemBlue
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        
        // Apply icon tint
        appearance.stackedLayoutAppearance.normal.iconColor = .secondaryLabel
        appearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
        appearance.inlineLayoutAppearance.normal.iconColor = .secondaryLabel
        appearance.inlineLayoutAppearance.selected.iconColor = .systemBlue
        appearance.compactInlineLayoutAppearance.normal.iconColor = .secondaryLabel
        appearance.compactInlineLayoutAppearance.selected.iconColor = .systemBlue
        
        // Apply to all tab bar states
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Enable smooth morphing animations
        UITabBar.appearance().isTranslucent = !reduceTransparency
        
        // Add subtle corner radius for modern look (reduced to prevent overlap)
        UITabBar.appearance().layer.cornerRadius = 16
        UITabBar.appearance().layer.masksToBounds = true
        
        // Add padding to prevent items from overlapping
        UITabBar.appearance().itemPositioning = .centered
        UITabBar.appearance().itemSpacing = 0
    }
}

// MARK: - Custom Liquid Glass Tab Bar Modifier (iOS 26 Enhancement)
struct LiquidGlassTabBarModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @State private var scrollOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .global).minY
                    )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollOffset = value
                }
            }
    }
}

// Preference key for tracking scroll position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func liquidGlassTabBar() -> some View {
        self.modifier(LiquidGlassTabBarModifier())
    }
}

#Preview {
    MainTabView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 0)),
        authManager: AuthenticationManager()
    )
}


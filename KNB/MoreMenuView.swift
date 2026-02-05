//
//  MoreMenuView.swift
//  KNB
//
//  Created by AI Assistant on 12/25/25.
//

import SwiftUI

struct MoreMenuView: View {
    @Binding var currentUser: User?
    @ObservedObject var authManager: AuthenticationManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var navigationManager: NavigationManager
    
    @State private var selectedOption: MenuOption?
    
    enum MenuOption: String, Identifiable {
        case account = "Account"
        case auction = "Auction"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .account: return "person.crop.circle.fill"
            case .auction: return "hammer.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .account: return .blue
            case .auction: return .orange
            }
        }
        
        var description: String {
            switch self {
            case .account: return "View your profile and activity"
            case .auction: return "Browse and bid on honors"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // User Header Card
                        VStack(spacing: 20) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.2),
                                                Color.purple.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 92, height: 92)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            // Greeting
                            VStack(spacing: 8) {
                                Text("Hello, \(currentUser?.name ?? "there")")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Text("What would you like to do today?")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 32)
                        .padding(.horizontal, 24)
                        
                        // Menu Options
                        VStack(spacing: 16) {
                            MenuOptionCard(
                                option: .account,
                                action: {
                                    selectedOption = .account
                                }
                            )
                            
                            MenuOptionCard(
                                option: .auction,
                                action: {
                                    selectedOption = .auction
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedOption) { option in
                NavigationStack {
                    Group {
                        switch option {
                        case .account:
                            ProfileTabView(
                                user: $currentUser,
                                authManager: authManager
                            )
                        case .auction:
                            AuctionListView(
                                firestoreManager: firestoreManager,
                                currentUser: $currentUser,
                                authManager: authManager
                            )
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                selectedOption = nil
                            } label: {
                                Text("Cancel")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .onChange(of: navigationManager.navigateToAuctionId) { _, honorId in
                // If there's a deep link to auction, open the auction sheet
                if honorId != nil {
                    selectedOption = .auction
                }
            }
        }
    }
}

// MARK: - Menu Option Card
struct MenuOptionCard: View {
    let option: MoreMenuView.MenuOption
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 20) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    option.color.opacity(0.15),
                                    option.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [option.color, option.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.rawValue)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(option.description)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    MoreMenuView(
        currentUser: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 0)),
        authManager: AuthenticationManager()
    )
    .environmentObject(FirestoreManager())
    .environmentObject(AppSettings())
}

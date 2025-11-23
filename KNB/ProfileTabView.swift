//
//  ProfileTabView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct ProfileTabView: View {
    @Binding var user: User?
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var firestoreManager: FirestoreManager
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var userSponsorships: [KiddushSponsorship] = []
    @State private var isLoadingSponsorships = false
    @State private var showSettings = false
    
    // Name editing state
    @State private var showNameEditor = false
    @State private var editedName = ""
    @State private var isUpdatingName = false
    @State private var nameUpdateMessage: String?
    
    init(user: Binding<User?>, authManager: AuthenticationManager, firestoreManager: FirestoreManager) {
        self._user = user
        self.authManager = authManager
        self.firestoreManager = firestoreManager
    }
    
    var userHonors: [Honor] {
        guard let userName = user?.name else { return [] }
        return firestoreManager.getUserHonors(userName: userName)
    }
    
    var userSponsorshipsCount: Int {
        guard let email = user?.email else { return 0 }
        // Count sponsorships from real-time data
        return firestoreManager.kiddushSponsorships.filter { $0.sponsorEmail == email }.count
    }
    
    func loadUserSponsorships() {
        guard let email = user?.email else {
            print("⚠️ No user email available for loading sponsorships")
            return
        }
        
        print("🔍 Loading sponsorships for: \(email)")
        isLoadingSponsorships = true
        
        Task {
            userSponsorships = await firestoreManager.fetchUserSponsorships(email: email)
            print("✅ Loaded \(userSponsorships.count) sponsorships for user")
            
            // Also check the real-time data
            let realtimeCount = firestoreManager.kiddushSponsorships.filter { $0.sponsorEmail == email }.count
            print("📊 Real-time listener has \(realtimeCount) sponsorships for user")
            print("📋 Total sponsorships in Firestore: \(firestoreManager.kiddushSponsorships.count)")
            
            isLoadingSponsorships = false
        }
    }
    
    func updateUserName() async {
        guard let email = user?.email else {
            nameUpdateMessage = "User email not found"
            return
        }
        
        isUpdatingName = true
        nameUpdateMessage = nil
        
        let success = await firestoreManager.updateUserName(email: email, newName: editedName)
        
        await MainActor.run {
            isUpdatingName = false
            
            if success {
                // Update local user object
                let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                user?.name = trimmedName
                
                // Update cache so all posts show new name immediately
                UserCacheManager.shared.updateCachedName(trimmedName, for: email)
                
                // Haptic feedback
                let feedbackGenerator = UINotificationFeedbackGenerator()
                feedbackGenerator.notificationOccurred(.success)
                
                nameUpdateMessage = "Name updated successfully!"
                
                // Close sheet after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showNameEditor = false
                    nameUpdateMessage = nil
                }
            } else {
                nameUpdateMessage = firestoreManager.errorMessage ?? "Failed to update name"
                
                // Haptic feedback for error
                let feedbackGenerator = UINotificationFeedbackGenerator()
                feedbackGenerator.notificationOccurred(.error)
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
                    VStack(spacing: 25) {
                        // Header with Profile title and Settings button
                        ZStack {
                            // Centered Profile title
                            VStack(spacing: 2) {
                                Text("Profile")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("My Activity")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Settings button - top right
                            HStack {
                                Spacer()
                                Button(action: {
                                    showSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.blue)
                                }
                                .padding(.trailing, 20)
                            }
                        }
                        .padding(.top, 8)
                        
                        // User Info Section with enhanced design
                        VStack(spacing: 20) {
                            // Avatar with clean border
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.88, green: 0.93, blue: 0.98),
                                                Color(red: 0.90, green: 0.94, blue: 0.99)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 130, height: 130)
                                    .shadow(color: Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.15), radius: 15, x: 0, y: 8)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.25, green: 0.5, blue: 0.92),
                                                Color(red: 0.3, green: 0.55, blue: 0.96)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .padding(.top, 20)
                            
                            VStack(spacing: 12) {
                                // Name display
                                Text(user?.name ?? "Member")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.primary, .primary.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                // Prominent Edit Name button
                                Button(action: {
                                    editedName = user?.name ?? ""
                                    showNameEditor = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Edit Name")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.25, green: 0.5, blue: 0.92),
                                                Color(red: 0.3, green: 0.55, blue: 0.96)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: Color(red: 0.25, green: 0.5, blue: 0.92).opacity(0.4), radius: 8, x: 0, y: 4)
                                }
                            }
                                
                                Text(user?.email ?? "")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Enhanced Member Badge
                            HStack(spacing: 8) {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Active Member")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.yellow.opacity(0.2), .orange.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.yellow.opacity(0.5), .orange.opacity(0.5)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .padding(.bottom, 10)
                        
                        // Enhanced Statistics Card
                        VStack(spacing: 16) {
                            EnhancedStatRow(
                                icon: "dollarsign.circle.fill",
                                title: "Total Auction Pledges",
                                value: "$\((user?.totalPledged ?? 0).toSafeInt())",
                                color: .green
                            )
                            
                            Divider()
                                .padding(.horizontal, 8)
                            
                            EnhancedStatRow(
                                icon: "calendar.badge.checkmark",
                                title: "Kiddush Sponsorships",
                                value: "\(userSponsorshipsCount)",
                                color: .blue
                            )
                            
                            Divider()
                                .padding(.horizontal, 8)
                            
                            EnhancedStatRow(
                                icon: "hammer.fill",
                                title: "Auction Honors",
                                value: "\(userHonors.count)",
                                color: .orange
                            )
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .padding(.horizontal)
                        
                        // Auction Honors Section
                        if !userHonors.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Image(systemName: "hammer.fill")
                                        .foregroundStyle(.orange)
                                    Text("My Auction Bids")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                }
                                .padding(.horizontal)
                                
                                VStack(spacing: 15) {
                                    ForEach(userHonors) { honor in
                                        HonorBidCard(honor: honor, userName: user?.name ?? "")
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Sponsorship History Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.blue)
                                Text("Sponsorship History")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal)
                            
                            if isLoadingSponsorships {
                                VStack(spacing: 15) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    Text("Loading sponsorships...")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(40)
                            } else if userSponsorships.isEmpty {
                                // Empty State
                                VStack(spacing: 15) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("No Sponsorships Yet")
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    
                                    Text("Visit the Calendar tab to sponsor a Kiddush")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(40)
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .padding(.horizontal)
                            } else {
                                // Sponsorship List
                                VStack(spacing: 15) {
                                    ForEach(userSponsorships) { sponsorship in
                                        SponsorshipCard(sponsorship: sponsorship)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Debug Menu Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .foregroundStyle(.purple)
                                Text("Debug Tools")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                DebugActionButton(
                                    title: "Clear Cache & Refresh Parsha Data",
                                    icon: "arrow.triangle.2.circlepath",
                                    color: .blue
                                ) {
                                    // Clear all caches and force reload
                                    CalendarCacheManager.shared.clearCache()
                                    UserDefaults.standard.set(0, forKey: "hebrew_cache_version")
                                    print("✅ Cache cleared! Close and reopen app to reload Parsha data.")
                                }
                                
                                DebugActionButton(
                                    title: "Reset All Bids",
                                    icon: "arrow.counterclockwise.circle.fill",
                                    color: .orange
                                ) {
                                    Task {
                                        await firestoreManager.resetAllBids()
                                    }
                                }
                                
                                DebugActionButton(
                                    title: "Reset All Honors",
                                    icon: "trash.circle.fill",
                                    color: .red
                                ) {
                                    Task {
                                        await firestoreManager.resetAllHonors()
                                    }
                                }
                                
                                DebugActionButton(
                                    title: "Delete All Sponsorships",
                                    icon: "calendar.badge.minus",
                                    color: .purple
                                ) {
                                    Task {
                                        await firestoreManager.deleteAllSponsorships()
                                    }
                                }
                                
                                // Admin only: Delete All Social Posts
                                if user?.isAdmin == true {
                                    DebugActionButton(
                                        title: "Delete All Social Posts",
                                        icon: "bubble.left.and.bubble.right.fill",
                                        color: .indigo
                                    ) {
                                        Task {
                                            await firestoreManager.deleteAllSocialPosts()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Debug Info
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Total Honors:")
                                        .font(.system(size: 14, design: .rounded))
                                    Spacer()
                                    Text("\(firestoreManager.honors.count)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.blue)
                                }
                                
                                HStack {
                                    Text("Total Sponsorships:")
                                        .font(.system(size: 14, design: .rounded))
                                    Spacer()
                                    Text("\(firestoreManager.kiddushSponsorships.count)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding(.top, 10)
                        
                        // Enhanced Sign Out Button
                        Button(action: {
                            authManager.signOut()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: 18))
                                Text("Sign Out")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Powered by App Sprout LLC
                        Text("Powered by App Sprout LLC")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(red: 0.4, green: 0.45, blue: 0.6).opacity(0.6))
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("") // Empty title so our custom toolbar principal shows
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Profile")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("My Activity")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Settings button
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            .sheet(isPresented: $showSettings) {
                SettingsView(appSettings: appSettings)
                    .preferredColorScheme(appSettings.colorScheme)
            }
            .sheet(isPresented: $showNameEditor) {
                NameEditorView(
                    currentName: user?.name ?? "",
                    editedName: $editedName,
                    isUpdating: $isUpdatingName,
                    updateMessage: $nameUpdateMessage,
                    onSave: {
                        await updateUserName()
                    }
                )
            }
            .onAppear {
                loadUserSponsorships()
                // Start listening to real-time updates
                firestoreManager.startListeningToSponsorships()
            }
            .onDisappear {
                firestoreManager.stopListeningToSponsorships()
            }
            .refreshable {
                loadUserSponsorships()
            }
            .onChange(of: firestoreManager.kiddushSponsorships) { _, _ in
                // Automatically update when sponsorships change
                loadUserSponsorships()
            }
        }
    }
    

// MARK: - Honor Bid Card
struct HonorBidCard: View {
    let honor: Honor
    let userName: String
    
    var isLeading: Bool {
        honor.currentWinner == userName
    }
    
    var userBid: Bid? {
        honor.bids.first { $0.bidderName == userName }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(honor.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    
                    Text(honor.description)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if honor.isSold {
                    if isLeading {
                        HStack(spacing: 5) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("Won!")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                    } else {
                        Text("Sold")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else if isLeading {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                        Text("Leading")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your Bid")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    if let bid = userBid {
                        Text("$\(bid.amount.toSafeInt())")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(isLeading ? .green : .orange)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Current Bid")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Text("$\(honor.currentBid.toSafeInt())")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isLeading ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Sponsorship Card
struct SponsorshipCard: View {
    let sponsorship: KiddushSponsorship
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: sponsorship.date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(formattedDate)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    
                    Text(sponsorship.occasion)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    if sponsorship.isPaid {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Paid")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text("Pending")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    if sponsorship.isAnonymous {
                        Text("Anonymous")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Amount
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.green)
                Text("$500")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Stat Row
struct ProfileStatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Enhanced Stat Row
struct EnhancedStatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            Spacer()
        }
    }
}

// MARK: - Debug Action Button
struct DebugActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(12)
        }
    }
}

#Preview {
    let authManager = AuthenticationManager()
    let firestoreManager = FirestoreManager()
    
    return ProfileTabView(
        user: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 1800)),
        authManager: authManager,
        firestoreManager: firestoreManager
    )
    .environmentObject(AppSettings())
}

// MARK: - Name Editor View
struct NameEditorView: View {
    let currentName: String
    @Binding var editedName: String
    @Binding var isUpdating: Bool
    @Binding var updateMessage: String?
    var onSave: () async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    private var isNameValid: Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 50
    }
    
    private var characterCountColor: Color {
        let count = editedName.count
        if count == 0 || count > 50 {
            return .red
        } else if count < 3 {
            return .orange
        } else {
            return .green
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
                
                VStack(spacing: 30) {
                    // Title section
                    VStack(spacing: 8) {
                        Text("Edit Your Name")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("This name will appear on your profile and future posts")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Text field card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        TextField("Enter your name", text: $editedName)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isNameValid ? Color.green.opacity(0.5) : Color.red.opacity(0.3),
                                        lineWidth: isNameValid ? 2 : 1
                                    )
                            )
                            .focused($isTextFieldFocused)
                            .disabled(isUpdating)
                        
                        // Character counter
                        HStack {
                            if !isNameValid {
                                Text(editedName.count < 3 ? "Minimum 3 characters" : "Maximum 50 characters")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(characterCountColor)
                            }
                            
                            Spacer()
                            
                            Text("\(editedName.count)/50")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(characterCountColor)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // Update message
                    if let message = updateMessage {
                        HStack(spacing: 8) {
                            Image(systemName: message.contains("success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(message.contains("success") ? .green : .red)
                            
                            Text(message)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(message.contains("success") ? .green : .red)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(message.contains("success") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Save button
                    Button(action: {
                        isTextFieldFocused = false
                        Task {
                            await onSave()
                        }
                    }) {
                        HStack(spacing: 10) {
                            if isUpdating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Updating...")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text("Save Changes")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: isNameValid && !isUpdating ? [.blue, .purple] : [.gray, .gray.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: isNameValid ? .blue.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                    }
                    .disabled(!isNameValid || isUpdating)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUpdating)
                }
            }
            .onAppear {
                // Auto-focus text field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }
}



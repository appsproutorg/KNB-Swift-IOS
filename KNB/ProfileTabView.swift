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
    
    @State private var userSponsorships: [KiddushSponsorship] = []
    @State private var isLoadingSponsorships = false
    
    var userHonors: [Honor] {
        guard let userName = user?.name else { return [] }
        return firestoreManager.getUserHonors(userName: userName)
    }
    
    var userSponsorshipsCount: Int {
        guard let email = user?.email else { return 0 }
        // Count sponsorships from real-time data
        return firestoreManager.kiddushSponsorships.filter { $0.sponsorEmail == email }.count
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
                        // User Info Section
                        VStack(spacing: 15) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 100))
                                .foregroundStyle(.blue)
                                .padding(.top, 30)
                            
                            Text(user?.name ?? "Member")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            
                            Text(user?.email ?? "")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 10)
                        
                        // Statistics Card
                        VStack(spacing: 20) {
                            ProfileStatRow(
                                icon: "dollarsign.circle.fill",
                                title: "Total Auction Pledges",
                                value: "$\((user?.totalPledged ?? 0).toSafeInt())",
                                color: .green
                            )
                            
                            Divider()
                            
                            ProfileStatRow(
                                icon: "calendar.badge.checkmark",
                                title: "Kiddush Sponsorships",
                                value: "\(userSponsorshipsCount)",
                                color: .blue
                            )
                            
                            Divider()
                            
                            ProfileStatRow(
                                icon: "gavel.fill",
                                title: "Auction Honors",
                                value: "\(userHonors.count)",
                                color: .orange
                            )
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        
                        // Auction Honors Section
                        if !userHonors.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Image(systemName: "gavel.fill")
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
                        
                        // Sign Out Button
                        Button(action: {
                            authManager.signOut()
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                Text("Sign Out")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
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

#Preview {
    ProfileTabView(
        user: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 1800)),
        authManager: AuthenticationManager(),
        firestoreManager: FirestoreManager()
    )
}


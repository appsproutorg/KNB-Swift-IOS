//
//  AuctionListView.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI

struct AuctionListView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    @ObservedObject var authManager: AuthenticationManager
    @State private var selectedHonor: Honor?
    @State private var searchText = ""
    
    var totalPledged: Double {
        firestoreManager.honors.reduce(0) { $0 + $1.currentBid }
    }
    
    var filteredHonors: [Honor] {
        if searchText.isEmpty {
            return firestoreManager.honors
        }
        return firestoreManager.honors.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Stats Section
                    VStack(spacing: 14) {
                        TotalPledgedCard(amount: totalPledged)
                        
                        HStack(spacing: 8) {
                            StatsCard(
                                icon: "hand.raised.fill",
                                title: "Active",
                                value: "\(firestoreManager.honors.filter { !$0.isSold }.count)",
                                color: .blue
                            )
                            
                            StatsCard(
                                icon: "checkmark.seal.fill",
                                title: "Sold",
                                value: "\(firestoreManager.honors.filter { $0.isSold }.count)",
                                color: .green
                            )
                            
                            StatsCard(
                                icon: "scroll.fill",
                                title: "Total",
                                value: "\(firestoreManager.honors.count)",
                                color: .purple
                            )
                        }
                        .frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    
                    // Honors List
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredHonors.enumerated()), id: \.element.id) { index, honor in
                            ModernHonorCard(honor: honor)
                                .onTapGesture {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedHonor = honor
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Torah Honors")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Live Auction")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search honors...")
            .sheet(item: $selectedHonor) { honor in
                HonorDetailView(
                    honor: honor,
                    currentUser: $currentUser,
                    firestoreManager: firestoreManager
                )
            }
        }
    }
}

// MARK: - Total Pledged Card
struct TotalPledgedCard: View {
    let amount: Double
    @State private var animatedAmount: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                
                Text("Total Pledged")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
            }
            
            Text("$\(animatedAmount.toSafeInt())")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .contentTransition(.numericText())
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .green.opacity(0.1), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                animatedAmount = amount
            }
        }
        .onChange(of: amount) { oldValue, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedAmount = newValue
            }
        }
    }
}

// MARK: - Stats Card
struct StatsCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color.gradient)
                .symbolRenderingMode(.hierarchical)
                .frame(height: 22)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(height: 28)
            
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Modern Honor Card
struct ModernHonorCard: View {
    let honor: Honor
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            HStack(alignment: .top, spacing: 12) {
                // Icon Badge
                ZStack {
                    Circle()
                        .fill(honor.isSold ? Color.green.gradient : Color.blue.gradient)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: honor.isSold ? "checkmark.seal.fill" : "scroll.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(honor.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(honor.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            
            // Divider
            Divider()
                .padding(.horizontal, 16)
            
            // Price Section
            HStack(spacing: 0) {
                // Current Bid
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "gavel.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        
                        Text("CURRENT BID")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("$\(honor.currentBid.toSafeInt())")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1, height: 40)
                
                // Buy Now
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        
                        Text("BUY NOW")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("$\(honor.buyNowPrice.toSafeInt())")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            
            // Winner Badge (if exists)
            if let winner = honor.currentWinner, !honor.isSold {
                Divider()
                    .padding(.horizontal, 16)
                
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Text("Leading:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Text(winner)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.orange.opacity(0.05))
            }
            
            // Sold Banner
            if honor.isSold {
                Divider()
                    .padding(.horizontal, 16)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Text("SOLD")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    if let winner = honor.currentWinner {
                        Text(winner)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(Color.green.opacity(0.08))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    honor.isSold ? Color.green.opacity(0.3) : Color.blue.opacity(0.1),
                    lineWidth: honor.isSold ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isPressed ? 0.12 : 0.06), radius: isPressed ? 8 : 12, x: 0, y: isPressed ? 3 : 6)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .opacity(honor.isSold ? 0.85 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @Binding var user: User?
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Profile Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 6) {
                            Text(user?.name ?? "Member")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Text(user?.email ?? "")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Stats Card
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green.gradient)
                                        .symbolRenderingMode(.hierarchical)
                                    
                                    Text("Total Pledged")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("$\((user?.totalPledged ?? 0).toSafeInt())")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                            }
                            
                            Spacer()
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Actions Section
                    VStack(spacing: 12) {
                        // Sign Out Button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            authManager.signOut()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.body.weight(.semibold))
                                
                                Text("Sign Out")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .red.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
    }
}

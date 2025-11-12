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
    
    var totalPledged: Double {
        firestoreManager.honors.reduce(0) { $0 + $1.currentBid }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Total pledged card
                        TotalPledgedCard(amount: totalPledged)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        // Honors list
                        LazyVStack(spacing: 15) {
                            ForEach(Array(firestoreManager.honors.enumerated()), id: \.element.id) { index, honor in
                                HonorCard(honor: honor)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4)) {
                                            selectedHonor = honor
                                        }
                                    }
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05), value: firestoreManager.honors)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .refreshable {
                    // TODO: Refresh from database
                }
            }
            .navigationTitle("KNB Bidding")
            .navigationBarTitleDisplayMode(.large)
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
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("Total Pledged So Far")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            HStack {
                Text("$\(animatedAmount.toSafeInt())")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                
                Spacer()
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
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

// MARK: - Honor Card
struct HonorCard: View {
    let honor: Honor
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(honor.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(honor.description)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if honor.isSold {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Current Bid")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Text("$\(honor.currentBid.toSafeInt())")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Buy Now")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Text("$\(honor.buyNowPrice.toSafeInt())")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                }
            }
            
            if let winner = honor.currentWinner {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    
                    Text("Leading: \(winner)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 5)
            }
            
            if honor.isSold {
                HStack {
                    Spacer()
                    Text("SOLD")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.green)
                        .cornerRadius(10)
                    Spacer()
                }
                .padding(.top, 5)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(isPressed ? 0.15 : 0.05), radius: isPressed ? 5 : 10, x: 0, y: isPressed ? 2 : 5)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(honor.isSold ? 0.7 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
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
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.blue)
                        .padding(.top, 30)
                    
                    Text(user?.name ?? "Member")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text(user?.email ?? "")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 15) {
                        StatRow(icon: "dollarsign.circle.fill", title: "Total Pledged", value: "$\((user?.totalPledged ?? 0).toSafeInt())")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Sign Out Button
                    Button(action: {
                        authManager.signOut()
                        dismiss()
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
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
            .navigationTitle("Profile")
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

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
        }
    }
}


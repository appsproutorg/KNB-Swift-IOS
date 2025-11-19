//
//  HonorDetailView.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import SwiftUI

struct HonorDetailView: View {
    let honor: Honor
    @Binding var currentUser: User?
    @ObservedObject var firestoreManager: FirestoreManager
    @Environment(\.dismiss) var dismiss
    
    @State private var bidAmount: String = ""
    @State private var comment: String = ""
    @State private var showingBidConfirmation = false
    @State private var showingBuyNowConfirmation = false
    @State private var showingBidHistory = false
    @State private var showingInvalidBidAlert = false
    @State private var invalidBidMessage = ""
    
    // Maximum allowed bid amount (1 million dollars)
    private let maxBidAmount: Double = 1_000_000
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        HonorHeaderView(honor: honor)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Current winning info
                        if !honor.isSold {
                            CurrentBidInfo(honor: honor)
                                .padding(.horizontal)
                        }
                        
                        // Bid section
                        if !honor.isSold {
                            BidSection(
                                bidAmount: $bidAmount,
                                comment: $comment,
                                onPlaceBid: placeBid,
                                onBuyNow: buyNow,
                                onShowHistory: { showingBidHistory = true },
                                buyNowPrice: honor.buyNowPrice,
                                currentBid: honor.currentBid
                            )
                            .padding(.horizontal)
                        } else {
                            SoldBanner(winner: honor.currentWinner ?? "Unknown", amount: honor.currentBid)
                                .padding(.horizontal)
                        }
                        
                        // Inline Bid History Preview
                        if !honor.bids.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Activity")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    
                                    Spacer()
                                    
                                    Button("View All") {
                                        showingBidHistory = true
                                    }
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    ForEach(Array(honor.bids.prefix(3).enumerated()), id: \.element.id) { index, bid in
                                        VStack(spacing: 0) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(bid.bidderName)
                                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                                    
                                                    Text(timeAgoString(from: bid.timestamp))
                                                        .font(.system(size: 12, design: .rounded))
                                                        .foregroundStyle(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("$\(bid.amount.toSafeInt())")
                                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                                    .foregroundStyle(index == 0 ? .green : .primary)
                                            }
                                            .padding()
                                            
                                            if index < min(honor.bids.count, 3) - 1 {
                                                Divider()
                                                    .padding(.leading)
                                            }
                                        }
                                    }
                                }
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle(honor.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Bid", isPresented: $showingBidConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Place Bid") {
                    confirmBid()
                }
            } message: {
                Text("Place a bid of $\(bidAmount)?")
            }
            .alert("Confirm Purchase", isPresented: $showingBuyNowConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Buy Now") {
                    confirmBuyNow()
                }
            } message: {
                Text("Purchase this honor for $\(honor.buyNowPrice.toSafeInt())?")
            }
            .alert("Invalid Bid", isPresented: $showingInvalidBidAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(invalidBidMessage)
            }
            .sheet(isPresented: $showingBidHistory) {
                BidHistoryView(bids: honor.bids)
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func placeBid() {
        // Check if honor is already sold
        guard !honor.isSold else {
            invalidBidMessage = "This honor has already been sold"
            showingInvalidBidAlert = true
            return
        }
        
        // Validate bid amount is a valid number
        guard let amount = Double(bidAmount) else {
            invalidBidMessage = "Please enter a valid bid amount"
            showingInvalidBidAlert = true
            return
        }
        
        // Check if bid is higher than current bid
        guard amount > honor.currentBid else {
            invalidBidMessage = "Your bid must be higher than the current bid of $\(honor.currentBid.toSafeInt())"
            showingInvalidBidAlert = true
            return
        }
        
        // Check if bid is less than or equal to max allowed
        guard amount <= maxBidAmount else {
            invalidBidMessage = "Bid amount cannot exceed $\(maxBidAmount.toSafeInt()). Please enter a reasonable amount."
            showingInvalidBidAlert = true
            return
        }
        
        // Check if bid is a reasonable positive number
        guard amount > 0 && !amount.isNaN && !amount.isInfinite else {
            invalidBidMessage = "Please enter a valid bid amount"
            showingInvalidBidAlert = true
            return
        }
        
        showingBidConfirmation = true
    }
    
    private func confirmBid() {
        guard let amount = Double(bidAmount),
              let user = currentUser else { return }
        
        // Extra safety check before confirming
        guard amount > 0 && amount <= maxBidAmount && !amount.isNaN && !amount.isInfinite else {
            invalidBidMessage = "Invalid bid amount"
            showingInvalidBidAlert = true
            return
        }
        
        let newBid = Bid(
            amount: amount,
            bidderName: user.name,
            comment: comment.isEmpty ? nil : comment
        )
        
        Task {
            // Haptic feedback on start
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            let success = await firestoreManager.placeBid(honorId: honor.id, bid: newBid)
            
            if success {
                // Success feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
                bidAmount = ""
                comment = ""
                
                // Update user's total pledged locally
                currentUser?.totalPledged += amount
                
                // Sync totalPledged to Firestore
                if let userEmail = currentUser?.email {
                    _ = await firestoreManager.updateUserTotalPledged(email: userEmail, amount: currentUser?.totalPledged ?? 0)
                }
                
                // Dismiss after successful bid
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }
    
    private func buyNow() {
        showingBuyNowConfirmation = true
    }
    
    private func confirmBuyNow() {
        guard let user = currentUser else { return }
        
        let buyNowBid = Bid(
            amount: honor.buyNowPrice,
            bidderName: user.name,
            comment: "Buy Now Purchase"
        )
        
        Task {
            // Haptic feedback on start
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            let success = await firestoreManager.buyNow(honorId: honor.id, bid: buyNowBid)
            
            if success {
                // Success feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
                // Update user's total pledged locally
                currentUser?.totalPledged += honor.buyNowPrice
                
                // Sync totalPledged to Firestore
                if let userEmail = currentUser?.email {
                    _ = await firestoreManager.updateUserTotalPledged(email: userEmail, amount: currentUser?.totalPledged ?? 0)
                }
                
                // Dismiss after successful purchase
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                }
            }
        }
    }
}

// MARK: - Honor Header View
struct HonorHeaderView: View {
    let honor: Honor
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "scroll.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            
            VStack(spacing: 8) {
                Text(honor.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text(honor.description)
                    .font(.system(size: 17, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Current Bid Info
struct CurrentBidInfo: View {
    let honor: Honor
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Current Bid")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Text("$\(honor.currentBid.toSafeInt())")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            if let winner = honor.currentWinner {
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Leading Bidder")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                        Text(winner)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Quick Bid Button
struct QuickBidButton: View {
    let amount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("+\(amount)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

// MARK: - Bid Section
struct BidSection: View {
    @Binding var bidAmount: String
    @Binding var comment: String
    let onPlaceBid: () -> Void
    let onBuyNow: () -> Void
    let onShowHistory: () -> Void
    let buyNowPrice: Double
    let currentBid: Double
    
    @State private var bidButtonPressed = false
    @State private var buyButtonPressed = false
    
    // Dynamic bid increments based on current bid
    private var bidIncrements: [Int] {
        if currentBid < 1000 {
            return [50, 100, 180, 360]
        } else if currentBid < 5000 {
            return [100, 250, 500, 1000]
        } else {
            return [250, 500, 1000, 2500]
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Bid input
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Your Bid")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    
                    Spacer()
                    
                    Text("Min: $\((currentBid + 1).toSafeInt())")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                // Quick Bid Buttons
                HStack(spacing: 10) {
                    ForEach(bidIncrements, id: \.self) { amount in
                        QuickBidButton(amount: amount) { updateBid(amount: amount) }
                    }
                }
                
                HStack {
                    Text("$")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    TextField("Enter amount", text: $bidAmount)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Comment
            VStack(alignment: .leading, spacing: 10) {
                Text("Comment (Optional)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                TextField("Add a comment...", text: $comment, axis: .vertical)
                    .lineLimit(2...4)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Action buttons
            VStack(spacing: 16) {
                Button(action: onPlaceBid) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Place Bid")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(bidButtonPressed ? 0.98 : 1.0)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { bidButtonPressed = true } }
                        .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { bidButtonPressed = false } }
                )
                
                // Buy Now Button
                Button(action: onBuyNow) {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Buy It Now for $\(buyNowPrice.toSafeInt())")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    .scaleEffect(buyButtonPressed ? 0.98 : 1.0)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { buyButtonPressed = true } }
                        .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { buyButtonPressed = false } }
                )
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
    }
    
    private func updateBid(amount: Int) {
        let newBid = currentBid + Double(amount)
        bidAmount = String(Int(newBid))
    }
}

// MARK: - Sold Banner
struct SoldBanner: View {
    let winner: String
    let amount: Double
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("SOLD")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
            
            VStack(spacing: 5) {
                Text("Winner: \(winner)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Text("Final Price: $\(amount.toSafeInt())")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(.green.opacity(0.1))
        .cornerRadius(20)
    }
}



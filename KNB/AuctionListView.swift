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
    
    // Sorting and Filtering
    enum SortOption: String, CaseIterable {
        case priceHighToLow = "Price: High to Low"
        case priceLowToHigh = "Price: Low to High"
        case mostActive = "Most Active"
        case nameAZ = "Name: A-Z"
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All Items"
        case active = "Active Only"
        case sold = "Sold Only"
        case myBids = "My Bids"
    }
    
    @State private var sortOption: SortOption = .priceHighToLow
    @State private var filterOption: FilterOption = .all
    
    var totalPledged: Double {
        firestoreManager.honors.reduce(0) { $0 + $1.currentBid }
    }
    
    var filteredHonors: [Honor] {
        var honors = firestoreManager.honors
        
        // 1. Filter
        switch filterOption {
        case .all:
            break
        case .active:
            honors = honors.filter { !$0.isSold }
        case .sold:
            honors = honors.filter { $0.isSold }
        case .myBids:
            if let userName = currentUser?.name {
                honors = honors.filter { honor in
                    honor.bids.contains { $0.bidderName == userName } || honor.currentWinner == userName
                }
            }
        }
        
        // 2. Search
        if !searchText.isEmpty {
            honors = honors.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 3. Sort
        switch sortOption {
        case .priceHighToLow:
            honors.sort { $0.currentBid > $1.currentBid }
        case .priceLowToHigh:
            honors.sort { $0.currentBid < $1.currentBid }
        case .mostActive:
            honors.sort { $0.bids.count > $1.bids.count }
        case .nameAZ:
            honors.sort { $0.name < $1.name }
        }
        
        return honors
    }
    
    var groupedHonors: [String: [Honor]] {
        Dictionary(grouping: filteredHonors, by: { $0.category })
    }
    
    var sortedCategories: [String] {
        groupedHonors.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if firestoreManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header Stats Section
                            AuctionStatsView(
                                totalPledged: totalPledged,
                                firestoreManager: firestoreManager,
                                currentUser: currentUser
                            )
                            
                            // Grouped Honors List
                            AuctionGroupedListView(
                                sortedCategories: sortedCategories,
                                groupedHonors: groupedHonors,
                                selectedHonor: $selectedHonor
                            )
                        }
                    }
                    .refreshable {
                        await firestoreManager.fetchHonors()
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search honors...")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Auction")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.5, blue: 0.92),
                                    Color(red: 0.3, green: 0.55, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Sort Menu
                        Menu {
                            Picker("Sort By", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        // Filter Menu
                        Menu {
                            Picker("Filter By", selection: $filterOption) {
                                ForEach(FilterOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
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

// MARK: - Subviews
struct AuctionStatsView: View {
    let totalPledged: Double
    @ObservedObject var firestoreManager: FirestoreManager
    let currentUser: User?
    
    var body: some View {
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
                    icon: "person.fill",
                    title: "My Bids",
                    value: "\(firestoreManager.honors.filter { $0.bids.contains { bid in bid.bidderName == currentUser?.name } }.count)",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

struct AuctionGroupedListView: View {
    let sortedCategories: [String]
    let groupedHonors: [String: [Honor]]
    @Binding var selectedHonor: Honor?
    
    var body: some View {
        LazyVStack(spacing: 25) {
            ForEach(sortedCategories, id: \.self) { category in
                VStack(alignment: .leading, spacing: 15) {
                    // Category Header
                    Text(category)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    ForEach(groupedHonors[category] ?? []) { honor in
                        ModernHonorCard(honor: honor)
                            .onTapGesture {
                                selectedHonor = honor
                            }
                            .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.bottom, 20)
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
    
    var isHot: Bool {
        honor.bids.count >= 3 && !honor.isSold
    }
    
    var progress: Double {
        guard honor.buyNowPrice > 0 else { return 0 }
        return min(honor.currentBid / honor.buyNowPrice, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            HStack(alignment: .top, spacing: 12) {
                // Icon Badge
                ZStack {
                    Circle()
                        .fill(honor.isSold ? Color.green.gradient : (isHot ? Color.orange.gradient : Color.blue.gradient))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: honor.isSold ? "checkmark.seal.fill" : (isHot ? "flame.fill" : "scroll.fill"))
                        .font(.title3)
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(honor.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        if isHot {
                            Text("HOT")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                    
                    Text(honor.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            
            // Progress Bar (if active)
            if !honor.isSold {
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack {
                        Text("\(Int(progress * 100))% of Buy Now")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(honor.bids.count) bids")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            // Divider
            Divider()
                .padding(.horizontal, 16)
            
            // Price Section
            HStack(spacing: 0) {
                // Current Bid
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.fill")
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
                    honor.isSold ? Color.green.opacity(0.3) : (isHot ? Color.orange.opacity(0.3) : Color.blue.opacity(0.1)),
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




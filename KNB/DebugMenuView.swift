//
//  DebugMenuView.swift
//  KNB
//
//  Created by AI Assistant on 11/12/25.
//

import SwiftUI

struct DebugMenuView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @State private var isExpanded = false
    @State private var showingResetBidsConfirmation = false
    @State private var showingResetHonorsConfirmation = false
    @State private var showingDeleteSponsorshipsConfirmation = false
    @State private var isProcessing = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    // Smart dragging states
    @State private var position = CGPoint(x: UIScreen.main.bounds.width - 100, y: UIScreen.main.bounds.height - 150)
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Backdrop when expanded
                if isExpanded {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }
                }
                
                // Floating debug button and menu
                VStack(spacing: 0) {
                    // Expanded menu panel
                    if isExpanded {
                        VStack(spacing: 12) {
                            // Drag handle indicator
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 40, height: 5)
                                .padding(.top, 8)
                            
                            Text("🛠️ Debug Menu")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.top, 5)
                                .padding(.bottom, 10)
                            
                            Divider()
                            
                            ScrollView {
                            VStack(spacing: 12) {
                                // Reset all bids button
                                DebugButton(
                                    title: "Reset All Bids",
                                    icon: "arrow.counterclockwise.circle.fill",
                                    color: .orange,
                                    isProcessing: isProcessing
                                ) {
                                    showingResetBidsConfirmation = true
                                }
                                
                                // Reset all honors button
                                DebugButton(
                                    title: "Reset All Honors",
                                    icon: "trash.circle.fill",
                                    color: .red,
                                    isProcessing: isProcessing
                                ) {
                                    showingResetHonorsConfirmation = true
                                }
                                
                                // Delete all sponsorships button
                                DebugButton(
                                    title: "Delete All Sponsorships",
                                    icon: "calendar.badge.minus",
                                    color: .purple,
                                    isProcessing: isProcessing
                                ) {
                                    showingDeleteSponsorshipsConfirmation = true
                                }
                                
                                // Debug info
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ℹ️ Info")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    
                                    HStack {
                                        Text("Total Honors:")
                                            .font(.system(size: 12, design: .rounded))
                                        Spacer()
                                        Text("\(firestoreManager.honors.count)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.blue)
                                    }
                                    
                                    HStack {
                                        Text("Total Sponsorships:")
                                            .font(.system(size: 12, design: .rounded))
                                        Spacer()
                                        Text("\(firestoreManager.kiddushSponsorships.count)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.blue)
                                    }
                                    
                                    HStack {
                                        Text("Active Bids:")
                                            .font(.system(size: 12, design: .rounded))
                                        Spacer()
                                        Text("\(firestoreManager.honors.filter { !$0.bids.isEmpty }.count)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                
                                Text("⚠️ These actions will affect the live database")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 5)
                            }
                            .padding(.horizontal, 15)
                            .padding(.bottom, 10)
                        }
                        .frame(maxHeight: 350)
                    }
                    .frame(width: 300)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 0)
                    .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Floating toggle button - Smart draggable!
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            // Grip dots indicator
                            if !isExpanded {
                                VStack(spacing: 3) {
                                    Circle().fill(.white.opacity(0.6)).frame(width: 4, height: 4)
                                    Circle().fill(.white.opacity(0.6)).frame(width: 4, height: 4)
                                    Circle().fill(.white.opacity(0.6)).frame(width: 4, height: 4)
                                }
                            }
                            
                            Image(systemName: isDragging ? "move.3d" : (isExpanded ? "xmark.circle.fill" : "wrench.and.screwdriver.fill"))
                                .font(.system(size: 20))
                                .rotationEffect(.degrees(isDragging ? 360 : 0))
                            
                            if !isExpanded {
                                Text("Debug")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, isExpanded ? 15 : 18)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: isDragging ? [Color.green, Color.teal] : [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(30)
                        .shadow(color: isDragging ? .green.opacity(0.5) : .blue.opacity(0.4), radius: isDragging ? 15 : 10, x: 0, y: 5)
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                    }
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                isDragging = false
                                
                                // Calculate final position
                                let newX = position.x + value.translation.width
                                let newY = position.y + value.translation.height
                                
                                // Smart edge snapping
                                let screenWidth = geometry.size.width
                                let screenHeight = geometry.size.height
                                let buttonWidth: CGFloat = 120
                                let buttonHeight: CGFloat = 50
                                
                                // Snap to nearest vertical edge (left or right)
                                let snappedX: CGFloat
                                if newX < screenWidth / 2 {
                                    // Snap to left edge
                                    snappedX = 20
                                } else {
                                    // Snap to right edge
                                    snappedX = screenWidth - buttonWidth - 20
                                }
                                
                                // Keep within vertical bounds
                                let snappedY = max(100, min(newY, screenHeight - buttonHeight - 100))
                                
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    position = CGPoint(x: snappedX, y: snappedY)
                                    dragOffset = .zero
                                }
                                
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                    )
                }
                .position(
                    x: position.x + dragOffset.width + 60,
                    y: position.y + dragOffset.height + 25
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
            }
        }
        .alert("Reset All Bids?", isPresented: $showingResetBidsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetBids()
            }
        } message: {
            Text("This will clear all bids and reset all honors to $0. This action cannot be undone.")
        }
        .alert("Reset All Honors?", isPresented: $showingResetHonorsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetHonors()
            }
        } message: {
            Text("This will delete all honors and re-initialize them to default state. All bids will be lost. This action cannot be undone.")
        }
        .alert("Delete All Sponsorships?", isPresented: $showingDeleteSponsorshipsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSponsorships()
            }
        } message: {
            Text("This will permanently delete all Kiddush sponsorships. This action cannot be undone.")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
    }
    
    // MARK: - Actions
    
    private func resetBids() {
        isProcessing = true
        Task {
            let success = await firestoreManager.resetAllBids()
            await MainActor.run {
                isProcessing = false
                if success {
                    successMessage = "All bids have been reset successfully!"
                    showingSuccessAlert = true
                    
                    // Haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
            }
        }
    }
    
    private func resetHonors() {
        isProcessing = true
        Task {
            let success = await firestoreManager.resetAllHonors()
            await MainActor.run {
                isProcessing = false
                if success {
                    successMessage = "All honors have been reset to initial state!"
                    showingSuccessAlert = true
                    
                    // Haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
            }
        }
    }
    
    private func deleteSponsorships() {
        isProcessing = true
        Task {
            await firestoreManager.deleteAllSponsorships()
            await MainActor.run {
                isProcessing = false
                successMessage = "All sponsorships have been deleted!"
                showingSuccessAlert = true
                
                // Haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Debug Button Component
struct DebugButton: View {
    let title: String
    let icon: String
    let color: Color
    let isProcessing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(12)
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1.0)
    }
}

// MARK: - Helper for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        
        DebugMenuView(firestoreManager: FirestoreManager())
    }
}


//
//  SeatingView.swift
//  KNB
//
//  Created by AI Assistant on 12/25/25.
//

import SwiftUI

struct SeatingLayoutMetrics {
    let isCompactPhone: Bool
    let sectionSpacing: CGFloat
    let sectionVerticalSpacing: CGFloat
    let sectionTitleBottomPadding: CGFloat
    let seatSize: CGFloat
    let seatSpacing: CGFloat
    let rowLabelWidth: CGFloat
    let rowLabelFontSize: CGFloat
    let sectionHorizontalPadding: CGFloat
    let sectionVerticalPadding: CGFloat
    let bemaWidth: CGFloat
    let bemaHeight: CGFloat
    let bemaIconSize: CGFloat
    let bemaTextSize: CGFloat
    let panelHorizontalInset: CGFloat
    let panelVerticalPadding: CGFloat
    let panelMaxWidth: CGFloat
    let panelButtonFontSize: CGFloat
    let panelButtonHorizontalPadding: CGFloat
    let panelButtonVerticalPadding: CGFloat
    
    init(containerWidth: CGFloat) {
        isCompactPhone = containerWidth <= 390
        sectionSpacing = isCompactPhone ? 8 : 12
        sectionVerticalSpacing = isCompactPhone ? 4 : 6
        sectionTitleBottomPadding = isCompactPhone ? 2 : 4
        seatSize = isCompactPhone ? 13 : 16
        seatSpacing = isCompactPhone ? 3 : 4
        rowLabelWidth = isCompactPhone ? 16 : 18
        rowLabelFontSize = isCompactPhone ? 8 : 9
        sectionHorizontalPadding = isCompactPhone ? 10 : 16
        sectionVerticalPadding = isCompactPhone ? 14 : 20
        bemaWidth = isCompactPhone ? 52 : 60
        bemaHeight = isCompactPhone ? 42 : 50
        bemaIconSize = isCompactPhone ? 12 : 14
        bemaTextSize = isCompactPhone ? 6 : 7
        panelHorizontalInset = isCompactPhone ? 16 : 20
        panelVerticalPadding = isCompactPhone ? 10 : 12
        panelMaxWidth = isCompactPhone ? 320 : 350
        panelButtonFontSize = isCompactPhone ? 12 : 13
        panelButtonHorizontalPadding = isCompactPhone ? 12 : 16
        panelButtonVerticalPadding = isCompactPhone ? 7 : 8
    }
}

// MARK: - Seat Model
struct Seat: Identifiable {
    let id: String
    let row: String
    let number: Int
    let section: String
    var isAvailable: Bool
    var isSelected: Bool
    var isOccupied: Bool
    
    init(
        id: String = UUID().uuidString,
        row: String,
        number: Int,
        section: String,
        isAvailable: Bool = true,
        isSelected: Bool = false,
        isOccupied: Bool = false
    ) {
        self.id = id
        self.row = row
        self.number = number
        self.section = section
        self.isAvailable = isAvailable
        self.isSelected = isSelected
        self.isOccupied = isOccupied
    }
}

// MARK: - Seating View
struct SeatingView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedSeats: Set<String> = []
    @State private var leftSectionSeats: [[Seat]] = []
    @State private var middleSectionSeats: [[Seat]] = []
    @State private var rightSectionSeats: [[Seat]] = []
    @State private var isReserving = false
    @State private var reservationError: String?
    
    private let leftRowLabels = ["L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8"]
    private let middleRowLabels = ["M1", "M2", "M3"]
    private let rightRowLabels = ["R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9"]
    
    private var backgroundColor: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.1, green: 0.1, blue: 0.15)] :
                [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.2) : .white
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                GeometryReader { geometry in
                    let metrics = SeatingLayoutMetrics(containerWidth: geometry.size.width)
                    
                    VStack(spacing: 0) {
                        // Aron Kodesh
                        AronKodeshView()
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        // Main seating area
                        VStack(spacing: 0) {
                            ScrollView(showsIndicators: false) {
                                HStack(alignment: .top, spacing: metrics.sectionSpacing) {
                                    // LEFT SECTION
                                    VStack(spacing: metrics.sectionVerticalSpacing) {
                                        Text("LEFT")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .padding(.bottom, metrics.sectionTitleBottomPadding)
                                        
                                        ForEach(Array(leftSectionSeats.enumerated()), id: \.offset) { idx, row in
                                            SectionRowView(
                                                rowLabel: leftRowLabels[idx],
                                                seats: row,
                                                selectedSeats: $selectedSeats,
                                                firestoreManager: firestoreManager,
                                                currentUser: $currentUser,
                                                metrics: metrics
                                            )
                                        }
                                    }
                                    
                                    // CENTER SECTION with Bema
                                    VStack(spacing: metrics.sectionVerticalSpacing) {
                                        Text("CENTER")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .padding(.bottom, metrics.sectionTitleBottomPadding)
                                        
                                        if middleSectionSeats.count > 0 {
                                            CenterRowView(
                                                rowLabel: middleRowLabels[0],
                                                seats: middleSectionSeats[0],
                                                selectedSeats: $selectedSeats,
                                                firestoreManager: firestoreManager,
                                                currentUser: $currentUser,
                                                metrics: metrics
                                            )
                                        }
                                        
                                        BemaView(metrics: metrics)
                                        
                                        ForEach(Array(middleSectionSeats.dropFirst().enumerated()), id: \.offset) { idx, row in
                                            CenterRowView(
                                                rowLabel: middleRowLabels[idx + 1],
                                                seats: row,
                                                selectedSeats: $selectedSeats,
                                                firestoreManager: firestoreManager,
                                                currentUser: $currentUser,
                                                metrics: metrics
                                            )
                                        }
                                    }
                                    
                                    // RIGHT SECTION
                                    VStack(spacing: metrics.sectionVerticalSpacing) {
                                        Text("RIGHT")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .padding(.bottom, metrics.sectionTitleBottomPadding)
                                        
                                        ForEach(Array(rightSectionSeats.enumerated()), id: \.offset) { idx, row in
                                            SectionRowView(
                                                rowLabel: rightRowLabels[idx],
                                                seats: row,
                                                selectedSeats: $selectedSeats,
                                                firestoreManager: firestoreManager,
                                                currentUser: $currentUser,
                                                metrics: metrics
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, metrics.sectionHorizontalPadding)
                                .padding(.vertical, metrics.sectionVerticalPadding)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(cardBackground)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, x: 0, y: 4)
                        )
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 8)
                        
                        // Bottom panel
                        SelectionPanelView(
                            selectedSeats: $selectedSeats,
                            isReserving: $isReserving,
                            onConfirm: confirmSeatReservations,
                            metrics: metrics
                        )
                    }
                }
            }
            .navigationTitle("Seating")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateSeatData()
                firestoreManager.startListeningToSeatReservations()
            }
            .onDisappear {
                firestoreManager.stopListeningToSeatReservations()
            }
            .onChange(of: firestoreManager.seatReservations) { _, _ in
                updateSeatDataWithReservations()
            }
            .alert("Reservation Error", isPresented: .constant(reservationError != nil)) {
                Button("OK") { reservationError = nil }
            } message: {
                if let error = reservationError { Text(error) }
            }
        }
    }
    
    private func generateSeatData() {
        // LEFT: 8 rows - first 2 have 3 seats, rest have 5
        leftSectionSeats = leftRowLabels.enumerated().map { idx, label in
            let count = idx < 2 ? 3 : 5
            return (1...count).map { Seat(row: label, number: $0, section: "left") }
        }
        
        // MIDDLE: 3 rows, 3 seats each
        middleSectionSeats = middleRowLabels.map { label in
            (1...3).map { Seat(row: label, number: $0, section: "middle") }
        }
        
        // RIGHT: 9 rows - first 2 have 3 seats, rest have 5
        rightSectionSeats = rightRowLabels.enumerated().map { idx, label in
            let count = idx < 2 ? 3 : 5
            return (1...count).map { Seat(row: label, number: $0, section: "right") }
        }
        
        updateSeatDataWithReservations()
    }
    
    private func updateSeatDataWithReservations() {
        func updateSection(_ seats: inout [[Seat]]) {
            for i in 0..<seats.count {
                for j in 0..<seats[i].count {
                    let seat = seats[i][j]
                    let reserved = firestoreManager.getSeatReservation(row: seat.row, number: seat.number) != nil
                    seats[i][j].isOccupied = reserved
                    seats[i][j].isAvailable = !reserved
                }
            }
        }
        updateSection(&leftSectionSeats)
        updateSection(&middleSectionSeats)
        updateSection(&rightSectionSeats)
    }
    
    private func findSeat(byId id: String) -> Seat? {
        let allSeats = leftSectionSeats.flatMap { $0 } + middleSectionSeats.flatMap { $0 } + rightSectionSeats.flatMap { $0 }
        return allSeats.first { $0.id == id }
    }
    
    private func confirmSeatReservations() {
        guard let email = currentUser?.email, let name = currentUser?.name else {
            reservationError = "Please log in to reserve seats"
            return
        }
        guard !selectedSeats.isEmpty else { return }
        
        isReserving = true
        Task {
            var failed: [String] = []
            for seatId in selectedSeats {
                guard let seat = findSeat(byId: seatId) else { continue }
                let success = await firestoreManager.reserveSeat(row: seat.row, number: seat.number, userEmail: email, userName: name)
                if !success { failed.append("\(seat.row)-\(seat.number)") }
            }
            await MainActor.run {
                isReserving = false
                if failed.isEmpty {
                    selectedSeats.removeAll()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    reservationError = "Could not reserve: \(failed.joined(separator: ", "))"
                }
            }
        }
    }
}

// MARK: - Bema View
struct BemaView: View {
    @Environment(\.colorScheme) var colorScheme
    let metrics: SeatingLayoutMetrics
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark ?
                            [Color(red: 0.35, green: 0.3, blue: 0.25), Color(red: 0.28, green: 0.24, blue: 0.2)] :
                            [Color(red: 0.88, green: 0.82, blue: 0.74), Color(red: 0.82, green: 0.76, blue: 0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: metrics.bemaWidth, height: metrics.bemaHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.5), lineWidth: 1)
                )
                .shadow(color: Color.orange.opacity(0.15), radius: 6, x: 0, y: 3)
            
            VStack(spacing: 2) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: metrics.bemaIconSize))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.9, green: 0.85, blue: 0.75) : Color(red: 0.5, green: 0.4, blue: 0.3))
                Text("BEMA")
                    .font(.system(size: metrics.bemaTextSize, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.9, green: 0.85, blue: 0.75) : Color(red: 0.5, green: 0.4, blue: 0.3))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Section Row View
struct SectionRowView: View {
    let rowLabel: String
    let seats: [Seat]
    @Binding var selectedSeats: Set<String>
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    let metrics: SeatingLayoutMetrics
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: metrics.seatSpacing) {
            Text(rowLabel)
                .font(.system(size: metrics.rowLabelFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? Color(red: 0.5, green: 0.55, blue: 0.7) : Color(red: 0.55, green: 0.6, blue: 0.7))
                .frame(width: metrics.rowLabelWidth, alignment: .trailing)
            
            HStack(spacing: metrics.seatSpacing) {
                ForEach(seats) { seat in
                    SeatView(seat: seat, selectedSeats: $selectedSeats, firestoreManager: firestoreManager, currentUser: $currentUser, metrics: metrics)
                }
            }
        }
    }
}

// MARK: - Center Row View (for middle section - centered alignment)
struct CenterRowView: View {
    let rowLabel: String
    let seats: [Seat]
    @Binding var selectedSeats: Set<String>
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    let metrics: SeatingLayoutMetrics
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: metrics.seatSpacing) {
            // Row label on left - but invisible spacer on right to balance
            Text(rowLabel)
                .font(.system(size: metrics.rowLabelFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? Color(red: 0.5, green: 0.55, blue: 0.7) : Color(red: 0.55, green: 0.6, blue: 0.7))
                .frame(width: metrics.rowLabelWidth, alignment: .trailing)
            
            // Seats
            HStack(spacing: metrics.seatSpacing) {
                ForEach(seats) { seat in
                    SeatView(seat: seat, selectedSeats: $selectedSeats, firestoreManager: firestoreManager, currentUser: $currentUser, metrics: metrics)
                }
            }
            
            // Invisible spacer to balance the row label
            Color.clear
                .frame(width: metrics.rowLabelWidth)
        }
    }
}

// MARK: - Aron Kodesh View
struct AronKodeshView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                
                Image(systemName: "star.of.david")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Rectangle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
            }
            .padding(.horizontal, 40)
            
            Text("ARON KODESH")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(colorScheme == .dark ? Color(red: 0.6, green: 0.7, blue: 0.9) : Color(red: 0.3, green: 0.4, blue: 0.6))
            
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark ?
                            [Color(red: 0.3, green: 0.35, blue: 0.5), Color(red: 0.25, green: 0.3, blue: 0.45)] :
                            [Color(red: 0.85, green: 0.88, blue: 0.95), Color(red: 0.8, green: 0.84, blue: 0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 140, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.6), lineWidth: 1)
                )
                .shadow(color: Color.blue.opacity(0.15), radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - Seat View
struct SeatView: View {
    let seat: Seat
    @Binding var selectedSeats: Set<String>
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    let metrics: SeatingLayoutMetrics
    @Environment(\.colorScheme) var colorScheme
    @State private var showReservationInfo = false
    
    private var isSelected: Bool { selectedSeats.contains(seat.id) }
    private var reservation: SeatReservation? { firestoreManager.getSeatReservation(row: seat.row, number: seat.number) }
    private var isMyReservation: Bool {
        guard let res = reservation, let email = currentUser?.email else { return false }
        return res.reservedBy == email
    }
    
    private var seatColor: Color {
        if reservation != nil {
            return isMyReservation ? .blue : (colorScheme == .dark ? Color(red: 0.25, green: 0.25, blue: 0.3) : Color(red: 0.65, green: 0.65, blue: 0.7))
        }
        return isSelected ? .blue : (colorScheme == .dark ? Color(red: 0.4, green: 0.45, blue: 0.55) : Color(red: 0.78, green: 0.82, blue: 0.9))
    }
    
    var body: some View {
        Button {
            if isMyReservation {
                Task {
                    if let res = reservation {
                        let success = await firestoreManager.cancelSeatReservation(row: seat.row, number: seat.number, userEmail: res.reservedBy)
                        if success { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    }
                }
            } else if reservation != nil {
                showReservationInfo = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    if selectedSeats.contains(seat.id) { selectedSeats.remove(seat.id) }
                    else { selectedSeats.insert(seat.id) }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(seatColor)
                .frame(width: metrics.seatSize, height: metrics.seatSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4), lineWidth: 0.5)
                )
                .shadow(color: isSelected ? Color.blue.opacity(0.4) : Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: isSelected ? 4 : 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .scaleEffect((isSelected || isMyReservation) ? 1.1 : 1.0)
        .sheet(isPresented: $showReservationInfo) {
            if let res = reservation { SeatReservationInfoView(reservation: res) }
        }
    }
}

// MARK: - Seat Reservation Info View
struct SeatReservationInfoView: View {
    let reservation: SeatReservation
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark ?
                        [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.1, green: 0.1, blue: 0.15)] :
                        [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Seat")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("\(reservation.row)-\(reservation.number)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reserved By")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue.opacity(0.2), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reservation.reservedByName)
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    Text(reservation.reservedBy)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reserved On")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text(reservation.timestamp, style: .date)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.2) : .white)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, x: 0, y: 4)
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Seat Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
        }
    }
}

// MARK: - Selection Panel View
struct SelectionPanelView: View {
    @Binding var selectedSeats: Set<String>
    @Binding var isReserving: Bool
    var onConfirm: () -> Void
    let metrics: SeatingLayoutMetrics
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showConfirmation = false
    @State private var wasReserving = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkRotation: Double = -90
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var circleScale: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0
    @State private var bounceOffset: CGFloat = 0
    
    private var availableColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.45, blue: 0.55) : Color(red: 0.78, green: 0.82, blue: 0.9)
    }
    private var takenColor: Color {
        colorScheme == .dark ? Color(red: 0.25, green: 0.25, blue: 0.3) : Color(red: 0.65, green: 0.65, blue: 0.7)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                LegendDot(color: availableColor, label: "Available")
                LegendDot(color: .blue, label: "Selected")
                LegendDot(color: takenColor, label: "Taken")
            }
            
            if showConfirmation {
                // Success confirmation view with animated elements
                HStack(spacing: 14) {
                    ZStack {
                        // Outer glow pulse
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .scaleEffect(pulseScale)
                            .opacity(glowOpacity)
                        
                        // Main circle
                        Circle()
                            .fill(LinearGradient(colors: [Color.green, Color.green.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)
                            .scaleEffect(circleScale)
                            .shadow(color: .green.opacity(0.6), radius: 10, x: 0, y: 4)
                        
                        // Checkmark
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(checkmarkScale)
                            .rotationEffect(.degrees(checkmarkRotation))
                    }
                    .offset(y: bounceOffset)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reservation Confirmed!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Your seat is reserved")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .opacity(textOpacity)
                    .offset(x: textOffset)
                }
                .transition(.opacity)
            } else if !selectedSeats.isEmpty {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(selectedSeats.count) Seat\(selectedSeats.count == 1 ? "" : "s")")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Tap to deselect")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation { selectedSeats.removeAll() }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: metrics.panelButtonFontSize, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                            .padding(.horizontal, metrics.panelButtonHorizontalPadding)
                            .padding(.vertical, metrics.panelButtonVerticalPadding)
                            .background(Capsule().fill(Color.red.opacity(0.15)))
                    }
                    
                    Button {
                        onConfirm()
                    } label: {
                        HStack(spacing: 4) {
                            if isReserving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            }
                            Text(isReserving ? "Reserving..." : "Confirm")
                                .font(.system(size: metrics.panelButtonFontSize, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, metrics.panelButtonHorizontalPadding)
                        .padding(.vertical, metrics.panelButtonVerticalPadding)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [.blue, .blue.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .disabled(isReserving)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, metrics.panelHorizontalInset)
        .padding(.vertical, metrics.panelVerticalPadding)
        .frame(maxWidth: metrics.panelMaxWidth)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .onChange(of: isReserving) { oldValue, newValue in
            // Track when we start reserving
            if newValue == true {
                wasReserving = true
            }
            // If reservation finished and seats are already empty, show confirmation
            if oldValue == true && newValue == false && selectedSeats.isEmpty && wasReserving {
                wasReserving = false
                triggerConfirmationAnimation()
            }
        }
        .onChange(of: selectedSeats) { oldValue, newValue in
            // Only show confirmation if we were in the middle of reserving (not from cancel)
            if oldValue.count > 0 && newValue.isEmpty && wasReserving && !isReserving {
                wasReserving = false
                triggerConfirmationAnimation()
            }
        }
    }
    
    private func triggerConfirmationAnimation() {
        // Reset all animation states
        checkmarkScale = 0
        checkmarkRotation = -90
        textOpacity = 0
        textOffset = 20
        circleScale = 0
        pulseScale = 1.0
        glowOpacity = 0
        bounceOffset = 0
        
        // Show confirmation
        withAnimation(.easeOut(duration: 0.15)) {
            showConfirmation = true
        }
        
        // 1. Circle pops in with overshoot
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.05)) {
            circleScale = 1.0
        }
        
        // 2. Glow appears
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            glowOpacity = 0.8
        }
        
        // 3. Checkmark rotates and scales in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.2)) {
            checkmarkScale = 1.0
            checkmarkRotation = 0
        }
        
        // 4. Bounce effect
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4).delay(0.25)) {
            bounceOffset = -8
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.4)) {
            bounceOffset = 0
        }
        
        // 5. Pulse the glow
        withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
            pulseScale = 1.3
            glowOpacity = 0.4
        }
        
        // 6. Text slides in
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.35)) {
            textOpacity = 1.0
            textOffset = 0
        }
        
        // Hide after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                showConfirmation = false
                circleScale = 0.5
                checkmarkScale = 0
                textOpacity = 0
                textOffset = -20
                glowOpacity = 0
            }
        }
    }
}

// MARK: - Legend Dot
struct LegendDot: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SeatingView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 0))
    )
}

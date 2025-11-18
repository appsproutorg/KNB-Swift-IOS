//
//  CalendarView.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import SwiftUI

struct CalendarView: View {
    @StateObject private var hebrewCalendarService = HebrewCalendarService()
    @ObservedObject var firestoreManager: FirestoreManager
    @Binding var currentUser: User?
    
    @State private var currentMonth = Date()
    @State private var selectedDate: Date?
    @State private var showingSponsorshipForm = false
    @State private var hebrewDatesCache: [Date: String] = [:]
    @State private var refreshTrigger = UUID()  // Force refresh when needed
    
    let calendar = Calendar.chicago
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Premium Header
                    VStack(spacing: 12) {
                        // Title with enhanced gradient
                        Text("Kiddush Sponsorship")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.2), radius: 8, x: 0, y: 3)
                        
                        // Month navigation with premium style
                        HStack(spacing: 16) {
                            Button(action: previousMonth) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 44, height: 44)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                            }
                            .symbolEffect(.bounce, value: currentMonth)
                            
                            Text(dateFormatter.string(from: currentMonth))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(minWidth: 180)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentMonth)
                            
                            Button(action: nextMonth) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 44, height: 44)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                            }
                            .symbolEffect(.bounce, value: currentMonth)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            Spacer(minLength: 8)
                        
                        // Modern Weekday Headers
                        HStack(spacing: 4) {
                            ForEach(Array(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].enumerated()), id: \.offset) { index, day in
                                VStack(spacing: 4) {
                                    Text(day)
                                        .font(.system(size: index >= 5 ? 14 : 13, weight: index >= 5 ? .bold : .semibold, design: .rounded))
                                        .foregroundStyle(
                                            index >= 5 
                                            ? LinearGradient(colors: [.blue, .purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [.secondary], startPoint: .leading, endPoint: .trailing)
                                        )
                                    
                                    // Highlight bar for Fri/Sat
                                    if index >= 5 {
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(height: 3)
                                    }
                                }
                                .frame(maxWidth: index == 6 ? .infinity : 45)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        
                        // Premium Calendar Grid
                        LazyVGrid(
                            columns: [
                                GridItem(.fixed(45), spacing: 5),  // Sun
                                GridItem(.fixed(45), spacing: 5),  // Mon
                                GridItem(.fixed(45), spacing: 5),  // Tue
                                GridItem(.fixed(45), spacing: 5),  // Wed
                                GridItem(.fixed(45), spacing: 5),  // Thu
                                GridItem(.fixed(45), spacing: 5),  // Fri
                                GridItem(.flexible(), spacing: 5)  // Sat (uses remaining space)
                            ],
                            spacing: 10
                        ) {
                            ForEach(Array(getDaysInMonth().enumerated()), id: \.offset) { index, date in
                                if let date = date {
                                    let shabbatTime = hebrewCalendarService.getShabbatTime(for: date)
                                    let sponsorship = firestoreManager.getSponsorship(for: date)
                                    let isShabbat = hebrewCalendarService.isShabbat(date)
                                    
                                    CalendarDayCell(
                                        date: date,
                                        hebrewDate: hebrewDatesCache[date],
                                        shabbatTime: shabbatTime,
                                        sponsorship: sponsorship,
                                        isShabbat: isShabbat,
                                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                                        currentUserEmail: currentUser?.email,
                                        isPastDate: calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
                                    )
                                    .onTapGesture {
                                        let isPastDate = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
                                        if isShabbat && !isPastDate {
                                            let startOfDay = calendar.startOfDay(for: date)
                                            print("🔍 Tapped date: \(date)")
                                            print("   StartOfDay: \(startOfDay)")
                                            print("   Is Shabbat: \(isShabbat)")
                                            print("   ShabbatTime: \(shabbatTime != nil ? "exists" : "nil")")
                                            print("   Parsha: '\(shabbatTime?.parsha ?? "none")'")
                                            print("   Sponsorship: \(sponsorship != nil ? "exists" : "nil")")
                                            
                                            selectedDate = date
                                            showingSponsorshipForm = true
                                        }
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 65)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .id(refreshTrigger)  // Force grid refresh when sponsorships change
                        
                        // Premium Legend Card
                        VStack(spacing: 18) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("How it works")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                            }
                            
                            VStack(spacing: 10) {
                                ModernLegendRow(
                                    color: .blue,
                                    label: "Available",
                                    description: "Tap to sponsor this Shabbat",
                                    icon: "hand.tap.fill"
                                )
                                
                                ModernLegendRow(
                                    color: .yellow,
                                    label: "Booked",
                                    description: "Already sponsored",
                                    icon: "checkmark.circle.fill"
                                )
                                
                                ModernLegendRow(
                                    color: .gray,
                                    label: "Past",
                                    description: "Cannot be booked",
                                    icon: "lock.fill"
                                )
                            }
                        }
                        .padding(24)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
                                
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.3),
                                                Color.purple.opacity(0.2),
                                                Color.blue.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 24)
                    }
                }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Clear old cache to get fresh data with correct date matching
                let cacheVersion = UserDefaults.standard.integer(forKey: "hebrew_cache_version")
                if cacheVersion < 6 {
                    print("🔄 Clearing cache for Shabbat date fix (candles Friday -> Shabbat Saturday)...")
                    CalendarCacheManager.shared.clearCache()
                    hebrewCalendarService.clearCache()
                    UserDefaults.standard.set(6, forKey: "hebrew_cache_version")
                }
                
                // Preload 90 days of data
                Task {
                    await hebrewCalendarService.preload90Days()
                }
                loadCalendarData()
                firestoreManager.startListeningToSponsorships()
                
                print("📊 Current sponsorships count: \(firestoreManager.kiddushSponsorships.count)")
            }
            .onDisappear {
                firestoreManager.stopListeningToSponsorships()
            }
            .onChange(of: currentMonth) { _, _ in
                loadCalendarData()
            }
            .onChange(of: firestoreManager.kiddushSponsorships) { _, newSponsorships in
                // Force UI refresh when sponsorships change
                print("🔄 Sponsorships updated! Count: \(newSponsorships.count)")
                refreshTrigger = UUID()  // This triggers a re-render
            }
            .sheet(isPresented: $showingSponsorshipForm, onDismiss: {
                // Force refresh when form is dismissed
                print("🔄 Form dismissed, forcing calendar refresh")
                Task {
                    // Reload sponsorships from Firestore
                    await firestoreManager.fetchKiddushSponsorships()
                    // Force UI refresh
                    refreshTrigger = UUID()
                }
            }) {
                if let date = selectedDate {
                    SponsorshipFormView(
                        shabbatDate: date,
                        shabbatTime: hebrewCalendarService.getShabbatTime(for: date),
                        currentUser: currentUser,
                        firestoreManager: firestoreManager
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        if horizontalAmount > 50 {
                            // Swipe right - previous month
                            previousMonth()
                        } else if horizontalAmount < -50 {
                            // Swipe left - next month
                            nextMonth()
                        }
                    }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    func getDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstDayOfMonth = monthInterval.start
        
        // Get the weekday of the first day (1 = Sunday, 7 = Saturday)
        let weekdayOfFirst = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Calculate how many empty cells we need at the beginning
        // Sunday = 1, so offset is weekdayOfFirst - 1
        let offset = weekdayOfFirst - 1
        
        // Get total days in month
        let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)
        let numDaysInMonth = range?.count ?? 0
        
        var days: [Date?] = []
        
        // Add nil for empty cells before month starts
        for _ in 0..<offset {
            days.append(nil)
        }
        
        // Add all days in the month - ensure they're startOfDay
        for day in 0..<numDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDayOfMonth) {
                let startOfDay = calendar.startOfDay(for: date)
                days.append(startOfDay)
            }
        }
        
        // Fill remaining cells to complete 6 weeks (42 cells total)
        while days.count < 42 {
            days.append(nil)
        }
        
        return days
    }
    
    func loadCalendarData() {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let year = components.year, let month = components.month else { return }
        
        print("📅 Loading calendar data for \(year)-\(month)")
        
        Task {
            // Fetch Shabbat times for this month
            await hebrewCalendarService.fetchShabbatTimes(for: year, month: month)
            
            print("🔍 Checking what shabbatTimes we have:")
            for (date, time) in hebrewCalendarService.shabbatTimes {
                print("   📅 \(date): parsha='\(time.parsha ?? "NONE")'")
            }
            
            print("🔍 Checking sponsorships:")
            for sponsorship in firestoreManager.kiddushSponsorships {
                let startOfDay = calendar.startOfDay(for: sponsorship.date)
                print("   💰 \(startOfDay) - \(sponsorship.sponsorEmail)")
            }
            
            // Fetch Hebrew dates for visible days
            for date in getDaysInMonth().compactMap({ $0 }) {
                if hebrewDatesCache[date] == nil {
                    if let hebrewDate = await hebrewCalendarService.fetchHebrewDate(for: date) {
                        hebrewDatesCache[date] = hebrewDate
                    }
                }
            }
            
            print("✅ Calendar data loaded. ShabbatTimes count: \(hebrewCalendarService.shabbatTimes.count)")
        }
    }
    
    func previousMonth() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    func nextMonth() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let hebrewDate: String?
    let shabbatTime: ShabbatTime?
    let sponsorship: KiddushSponsorship?
    let isShabbat: Bool
    let isCurrentMonth: Bool
    let currentUserEmail: String?
    let isPastDate: Bool
    
    let calendar = Calendar.chicago
    
    var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var dayNumber: Int {
        calendar.component(.day, from: date)
    }
    
    var isSponsoredByCurrentUser: Bool {
        guard let email = currentUserEmail, let sponsorship = sponsorship else { return false }
        return sponsorship.sponsorEmail == email
    }
    
    var sponsorDisplayName: String? {
        guard let sponsorship = sponsorship else { return nil }
        if sponsorship.isAnonymous && !isSponsoredByCurrentUser {
            return "Sponsored"
        }
        return sponsorship.sponsorName
    }
    
    var isAvailableForSponsorship: Bool {
        return !isPastDate && sponsorship == nil
    }
    
    var body: some View {
        ZStack {
            // Premium cell background
            cellBackgroundMaterial
            
            // Content layer
            VStack(spacing: isShabbat ? 5 : 3) {
                // Top status indicator
                HStack {
                    Spacer()
                    if sponsorship != nil {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.9), .orange.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 8, height: 8)
                                .shadow(color: .yellow.opacity(0.5), radius: 2, x: 0, y: 1)
                            
                            Circle()
                                .stroke(.white.opacity(0.6), lineWidth: 1.5)
                                .frame(width: 8, height: 8)
                        }
                    } else if isPastDate && isShabbat {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
                .frame(height: 12)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                Spacer(minLength: 2)
                
                // Gregorian date with gradient for Shabbat
                Text("\(dayNumber)")
                    .font(.system(size: isShabbat ? 24 : 17, weight: isToday ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(
                        isPastDate 
                        ? LinearGradient(colors: [.secondary.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                        : (sponsorship != nil && isShabbat
                           ? LinearGradient(colors: [Color(red: 0.95, green: 0.65, blue: 0.15), Color(red: 0.9, green: 0.6, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                           : (isShabbat && isCurrentMonth 
                              ? LinearGradient(colors: [.blue, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [isCurrentMonth ? .primary : .secondary.opacity(0.4)], startPoint: .top, endPoint: .bottom)))
                    )
                    .shadow(color: (isShabbat && !isPastDate) ? (sponsorship != nil ? Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.3) : .blue.opacity(0.2)) : .clear, radius: 3, x: 0, y: 1)
                    .onAppear {
                        if isShabbat && isCurrentMonth {
                            print("🔍 Cell \(dayNumber): Shabbat=\(isShabbat), ShabbatTime=\(shabbatTime != nil), Parsha='\(shabbatTime?.parsha ?? "none")', Sponsored=\(sponsorship != nil)")
                        }
                    }
                
                // Hebrew Date
                if let hebrewDate = hebrewDate, isCurrentMonth {
                    Text(hebrewDate)
                        .font(.system(size: isShabbat ? 10 : 7, weight: isShabbat ? .medium : .regular, design: .rounded))
                        .foregroundStyle(
                            isPastDate 
                            ? Color.secondary.opacity(0.4)
                            : (sponsorship != nil && isShabbat
                               ? Color(red: 0.9, green: 0.6, blue: 0.15).opacity(0.9)
                               : (isShabbat ? Color.blue.opacity(0.8) : Color.secondary))
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 4)
                }
                
                // Shabbat details
                if isShabbat, isCurrentMonth {
                    if let shabbatTime = shabbatTime, let parsha = shabbatTime.parsha {
                        Text(parsha)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                isPastDate 
                                ? LinearGradient(colors: [Color.secondary.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                                : (sponsorship != nil
                                   ? LinearGradient(colors: [Color(red: 0.9, green: 0.6, blue: 0.1), Color(red: 0.95, green: 0.7, blue: 0.2)], startPoint: .leading, endPoint: .trailing)
                                   : LinearGradient(colors: [.blue, .purple.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        isPastDate 
                                        ? Color.clear 
                                        : (sponsorship != nil 
                                           ? Color(red: 1.0, green: 0.8, blue: 0.3).opacity(0.15)
                                           : Color.blue.opacity(0.08))
                                    )
                                    .shadow(
                                        color: isPastDate 
                                        ? Color.clear 
                                        : (sponsorship != nil 
                                           ? Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.15)
                                           : Color.blue.opacity(0.1)), 
                                        radius: 2, x: 0, y: 1
                                    )
                            )
                    }
                }
                
                Spacer(minLength: 2)
            }
            .padding(1) // Small padding to prevent border clipping
        }
        .frame(maxWidth: .infinity)
        .frame(height: isShabbat ? 92 : 68)
        .overlay(
            Group {
                if isToday {
                    // Today ring indicator (takes priority)
                    RoundedRectangle(cornerRadius: isShabbat ? 18 : 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.blue, .purple.opacity(0.8), .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3.5
                        )
                        .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 4)
                } else {
                    // Regular cell overlay
                    cellOverlay
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isShabbat ? 18 : 14))
        .opacity(isCurrentMonth ? (isPastDate ? 0.6 : 1.0) : 0.3)
        .scaleEffect(isToday ? 1.03 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isToday)
    }
    
    // Premium cell backgrounds with materials and gradients
    @ViewBuilder
    var cellBackgroundMaterial: some View {
        ZStack {
            // Base material layer
            RoundedRectangle(cornerRadius: isShabbat ? 18 : 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(sponsorship != nil ? 0.08 : 0.06), radius: sponsorship != nil ? 10 : 8, x: 0, y: sponsorship != nil ? 4 : 3)
            
            // Status-based gradient overlays
            if let _ = sponsorship {
                // Sponsored - elegant gold gradient (works for both Shabbat and regular)
                RoundedRectangle(cornerRadius: isShabbat ? 18 : 14)
                    .fill(
                        LinearGradient(
                            colors: isShabbat ? [
                                // Sponsored Shabbat gets a richer gold-amber gradient
                                Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.25),
                                Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.18),
                                Color(red: 1.0, green: 0.8, blue: 0.35).opacity(0.15)
                            ] : [
                                // Regular sponsored days
                                .yellow.opacity(0.2),
                                .orange.opacity(0.15),
                                .yellow.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if isShabbat && isCurrentMonth && !isPastDate {
                // Available Shabbat - premium blue gradient
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                .blue.opacity(0.12),
                                .purple.opacity(0.08),
                                .blue.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if isPastDate && isShabbat {
                // Past Shabbat - subtle gray
                RoundedRectangle(cornerRadius: 18)
                    .fill(.gray.opacity(0.06))
            }
        }
    }
    
    // Premium borders with gradients
    @ViewBuilder
    var cellOverlay: some View {
        if sponsorship != nil {
            // Sponsored dates get elegant gold border
            RoundedRectangle(cornerRadius: isShabbat ? 18 : 14)
                .stroke(
                    LinearGradient(
                        colors: isShabbat ? [
                            // Sponsored Shabbat gets a beautiful gold border
                            Color(red: 1.0, green: 0.82, blue: 0.25),
                            Color(red: 1.0, green: 0.75, blue: 0.18),
                            Color(red: 1.0, green: 0.8, blue: 0.22)
                        ] : [
                            .yellow.opacity(0.7),
                            .orange.opacity(0.5),
                            .yellow.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isShabbat ? 3 : 2.5
                )
                .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.4), radius: 8, x: 0, y: 4)
        } else if isShabbat && isAvailableForSponsorship && isCurrentMonth {
            // Available Shabbats get beautiful blue-purple gradient border
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            .blue.opacity(0.7),
                            .purple.opacity(0.6),
                            .blue.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .shadow(color: .blue.opacity(0.25), radius: 6, x: 0, y: 3)
        } else if isCurrentMonth {
            // Regular dates get subtle border
            RoundedRectangle(cornerRadius: isShabbat ? 18 : 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    CalendarView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 0))
    )
}

// MARK: - Modern Legend Row Component
struct ModernLegendRow: View {
    let color: Color
    let label: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 14) {
            // Premium icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: color.opacity(0.2), radius: 3, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Additional Calendar Enhancements
extension CalendarView {
    // Add subtle haptic feedback for interactions
    private func provideFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}



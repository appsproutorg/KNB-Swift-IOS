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
    
    let calendar = Calendar.current
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
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
                        // Month Navigation
                        HStack {
                            Button(action: previousMonth) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text(dateFormatter.string(from: currentMonth))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            
                            Spacer()
                            
                            Button(action: nextMonth) {
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Weekday Headers
                        HStack(spacing: 0) {
                            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                                Text(day)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Calendar Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(getDaysInMonth(), id: \.self) { date in
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
                                        isPastDate: date < Date()
                                    )
                                    .onTapGesture {
                                        let isPastDate = date < Date()
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
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .id(refreshTrigger)  // Force grid refresh when sponsorships change
                        
                        // Legend with modern glassy design
                        VStack(spacing: 12) {
                            Text("Legend")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 10) {
                                LegendItem(
                                    color: .blue.opacity(0.2),
                                    text: "Available Shabbat",
                                    icon: "calendar.badge.plus"
                                )
                                
                                LegendItem(
                                    color: .red.opacity(0.6),
                                    text: "Already Sponsored",
                                    icon: "checkmark.seal.fill"
                                )
                                
                                LegendItem(
                                    color: .gray.opacity(0.4),
                                    text: "Past Date (Unavailable)",
                                    icon: "lock.fill"
                                )
                            }
                            .frame(maxWidth: .infinity)
                            
                            Text("Tap any available Shabbat to sponsor. Past dates cannot be booked.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        )
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle("Kiddush Sponsorship")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Clear old cache to get fresh Parsha data with new parsing
                let cacheVersion = UserDefaults.standard.integer(forKey: "hebrew_cache_version")
                if cacheVersion < 3 {
                    print("🔄 Clearing cache for updated Parsha parsing...")
                    CalendarCacheManager.shared.clearCache()
                    hebrewCalendarService.clearCache()
                    UserDefaults.standard.set(3, forKey: "hebrew_cache_version")
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
                refreshTrigger = UUID()
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
    
    let calendar = Calendar.current
    
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
        VStack(spacing: 1) {
            // Gregorian Date
            Text("\(dayNumber)")
                .font(.system(size: 18, weight: isToday ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isPastDate ? Color.secondary.opacity(0.4) : (isCurrentMonth ? .primary : Color.secondary.opacity(0.3)))
                .padding(.top, 2)
                .onAppear {
                    if isShabbat && isCurrentMonth {
                        print("🔍 Cell \(dayNumber): Shabbat=\(isShabbat), ShabbatTime=\(shabbatTime != nil), Parsha='\(shabbatTime?.parsha ?? "none")', Sponsored=\(sponsorship != nil)")
                    }
                }
            
            // Hebrew Date (full date without year)
            if let hebrewDate = hebrewDate, isCurrentMonth {
                Text(hebrewDate)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(isPastDate ? Color.secondary.opacity(0.3) : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(height: 16)
            }
            
            // Parsha name for Shabbat
            if isShabbat, isCurrentMonth {
                if let shabbatTime = shabbatTime, let parsha = shabbatTime.parsha {
                    Text(parsha)
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(isPastDate ? Color.secondary.opacity(0.3) : .blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 2)
                } else {
                    // Debug: Show if we're missing parsha data
                    Text("No Parsha")
                        .font(.system(size: 6, design: .rounded))
                        .foregroundStyle(.red.opacity(0.3))
                }
            }
            
            // Candle lighting time
            if let shabbatTime = shabbatTime, isCurrentMonth {
                Text(formatTime(shabbatTime.candleLighting))
                    .font(.system(size: 7, design: .rounded))
                    .foregroundStyle(isPastDate ? Color.secondary.opacity(0.3) : .orange)
            }
            
            // Past date indicator
            if isPastDate && isShabbat && isCurrentMonth {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(cellBackgroundMaterial)
        .overlay(cellOverlay)
        .opacity(isCurrentMonth ? (isPastDate ? 0.4 : 1.0) : 0.3)
        .animation(.easeInOut(duration: 0.2), value: isPastDate)
    }
    
    // Modern glassy background with smooth transitions
    @ViewBuilder
    var cellBackgroundMaterial: some View {
        if let _ = sponsorship {
            // Sponsored dates get a red glassy effect
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.red.opacity(0.15))
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            }
        } else if isShabbat && isCurrentMonth && !isPastDate {
            // Available Shabbat dates get a blue glassy effect
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.08))
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            }
        } else if isPastDate && isShabbat {
            // Past dates get a muted gray glassy effect
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.05))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.clear)
        }
    }
    
    // Glassy border overlay with glow effect
    @ViewBuilder
    var cellOverlay: some View {
        if isToday {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .shadow(color: .blue.opacity(0.4), radius: 4, x: 0, y: 2)
        } else if isShabbat && isAvailableForSponsorship && isCurrentMonth {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.blue.opacity(0.2), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.clear, lineWidth: 0)
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

// MARK: - Legend Item Component
struct LegendItem: View {
    let color: Color
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
            
            Spacer()
        }
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


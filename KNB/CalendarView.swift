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
                
                VStack(spacing: 0) {
                    // Custom Animated Header
                    VStack(spacing: 8) {
                        // Title with gradient
                        Text("Kiddush Sponsorship")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.15), radius: 4, x: 0, y: 2)
                        
                        // Month/Year with navigation - now more compact
                        HStack(spacing: 12) {
                            Button(action: previousMonth) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.blue.opacity(0.8))
                                    .symbolEffect(.bounce, value: currentMonth)
                            }
                            
                            Text(dateFormatter.string(from: currentMonth))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentMonth)
                            
                            Button(action: nextMonth) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.blue.opacity(0.8))
                                    .symbolEffect(.bounce, value: currentMonth)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer(minLength: 12)
                        
                        // Weekday Headers with wider Saturday
                        HStack(spacing: 4) {
                            ForEach(Array(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].enumerated()), id: \.offset) { index, day in
                                Text(day)
                                    .font(.system(size: index == 6 ? 14 : 12, weight: index == 6 ? .bold : .semibold, design: .rounded))
                                    .foregroundStyle(index == 6 ? .blue : .secondary)
                                    .frame(maxWidth: index == 6 ? .infinity : 45)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Calendar Grid with wider Shabbat columns - using fixed widths to fit screen
                        LazyVGrid(
                            columns: [
                                GridItem(.fixed(45), spacing: 4),  // Sun
                                GridItem(.fixed(45), spacing: 4),  // Mon
                                GridItem(.fixed(45), spacing: 4),  // Tue
                                GridItem(.fixed(45), spacing: 4),  // Wed
                                GridItem(.fixed(45), spacing: 4),  // Thu
                                GridItem(.fixed(45), spacing: 4),  // Fri
                                GridItem(.flexible(), spacing: 4)  // Sat (uses remaining space)
                            ],
                            spacing: 8
                        ) {
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
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                                        .padding(.horizontal, 16)
                                        .id(refreshTrigger)  // Force grid refresh when sponsorships change
                        
                        // Clear, easy-to-understand legend
                        VStack(spacing: 16) {
                            Text("How it works")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 12) {
                                SimpleLegendRow(
                                    color: .blue,
                                    label: "Available",
                                    description: "Tap to sponsor this Shabbat"
                                )
                                
                                SimpleLegendRow(
                                    color: .yellow,
                                    label: "Booked",
                                    description: "Already sponsored"
                                )
                                
                                SimpleLegendRow(
                                    color: .gray,
                                    label: "Past",
                                    description: "Cannot be booked"
                                )
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.secondary.opacity(0.15), Color.secondary.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                }
                }
            }
            .navigationBarHidden(true)
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
        VStack(spacing: isShabbat ? 4 : 2) {
            // Status badge (top-right for Shabbat, center for regular days)
            if sponsorship != nil || (isPastDate && isShabbat) {
                HStack {
                    Spacer()
                    if sponsorship != nil {
                        Circle()
                            .fill(.yellow)
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle()
                                    .stroke(.yellow.opacity(0.5), lineWidth: 2)
                            )
                    } else if isPastDate && isShabbat {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 6)
                .padding(.top, 6)
            } else {
                Spacer()
                    .frame(height: 16)
            }
            
            // Gregorian Date Number - Responsive sizing
            Text("\(dayNumber)")
                .font(.system(size: isShabbat ? 22 : 16, weight: isToday ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isPastDate ? Color.secondary.opacity(0.5) : (isCurrentMonth ? .primary : Color.secondary.opacity(0.4)))
                .onAppear {
                    if isShabbat && isCurrentMonth {
                        print("🔍 Cell \(dayNumber): Shabbat=\(isShabbat), ShabbatTime=\(shabbatTime != nil), Parsha='\(shabbatTime?.parsha ?? "none")', Sponsored=\(sponsorship != nil)")
                    }
                }
            
            // Shabbat-specific details
            if isShabbat, isCurrentMonth {
                // Parsha name
                if let shabbatTime = shabbatTime, let parsha = shabbatTime.parsha {
                    Text(parsha)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(isPastDate ? Color.secondary.opacity(0.5) : .blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                }
                
                // Candle lighting time
                if let shabbatTime = shabbatTime {
                    HStack(spacing: 2) {
                        Image(systemName: "light.max")
                            .font(.system(size: 7))
                        Text(formatTime(shabbatTime.candleLighting))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(isPastDate ? Color.secondary.opacity(0.4) : .orange)
                    .padding(.top, 1)
                }
            }
            
            Spacer(minLength: 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isShabbat ? 85 : 65)
        .background(cellBackgroundMaterial)
        .overlay(cellOverlay)
        .opacity(isCurrentMonth ? (isPastDate ? 0.5 : 1.0) : 0.25)
        .scaleEffect(isToday ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isToday)
    }
    
    // Simple box backgrounds with status colors
    @ViewBuilder
    var cellBackgroundMaterial: some View {
        ZStack {
            // Base background - simple box
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
            
            // Status-based color overlay
            if let _ = sponsorship {
                // Sponsored - yellow/amber (already booked)
                RoundedRectangle(cornerRadius: 10)
                    .fill(.yellow.opacity(0.25))
            } else if isShabbat && isCurrentMonth && !isPastDate {
                // Available Shabbat - light blue (can book)
                RoundedRectangle(cornerRadius: 10)
                    .fill(.blue.opacity(0.08))
            } else if isPastDate && isShabbat {
                // Past Shabbat - gray (locked)
                RoundedRectangle(cornerRadius: 10)
                    .fill(.gray.opacity(0.08))
            }
        }
    }
    
    // Simple box borders
    @ViewBuilder
    var cellOverlay: some View {
        if isToday {
            // Today gets a prominent blue border
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.blue, lineWidth: 2.5)
        } else if sponsorship != nil {
            // Sponsored dates get yellow border
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.yellow.opacity(0.6), lineWidth: 2)
        } else if isShabbat && isAvailableForSponsorship && isCurrentMonth {
            // Available Shabbats get blue border
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.blue.opacity(0.3), lineWidth: 2)
        } else if isCurrentMonth {
            // Regular dates get light border
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.clear, lineWidth: 0)
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

// MARK: - Simple Legend Row Component
struct SimpleLegendRow: View {
    let color: Color
    let label: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            // Color indicator circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
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


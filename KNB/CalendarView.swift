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
    @State private var isRefreshing = false
    
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
                
                // Loading overlay
                if hebrewCalendarService.isLoading && !isRefreshing {
                    VStack {
                        Spacer()
                        ProgressView("Loading calendar data...")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(15)
                        Spacer()
                    }
                    .zIndex(1)
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Pull to Refresh Indicator
                        if isRefreshing {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.top, 10)
                                Spacer()
                            }
                        }
                        
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
                            
                            VStack(spacing: 4) {
                                Text(dateFormatter.string(from: currentMonth))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                
                                // "Today" button if not viewing current month
                                if !calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month) {
                                    Button(action: goToToday) {
                                        Text("Today")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(.blue.opacity(0.1))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            
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
                                        isPast: date < calendar.startOfDay(for: Date())
                                    )
                                    .onTapGesture {
                                        // Only allow tapping future Shabbat dates
                                        if isShabbat && date >= calendar.startOfDay(for: Date()) {
                                            // Haptic feedback
                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                            impact.impactOccurred()
                                            
                                            selectedDate = date
                                            showingSponsorshipForm = true
                                        } else if isShabbat && date < calendar.startOfDay(for: Date()) {
                                            // Light haptic for invalid tap
                                            let notification = UINotificationFeedbackGenerator()
                                            notification.notificationOccurred(.warning)
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
                        
                        // Legend
                        VStack(spacing: 12) {
                            Text("Legend")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 12, height: 12)
                                    Text("Future Shabbat (available)")
                                        .font(.system(size: 14, design: .rounded))
                                    Spacer()
                                }
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.yellow.opacity(0.4))
                                        .frame(width: 12, height: 12)
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.yellow)
                                        Text("Your sponsorship")
                                            .font(.system(size: 14, design: .rounded))
                                    }
                                    Spacer()
                                }
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.red.opacity(0.6))
                                        .frame(width: 12, height: 12)
                                    Text("Sponsored by others")
                                        .font(.system(size: 14, design: .rounded))
                                    Spacer()
                                }
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                    Text("Past dates (unavailable)")
                                        .font(.system(size: 14, design: .rounded))
                                    Spacer()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            Text("Tap any future Shabbat to sponsor or view details")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
                    .refreshable {
                        await refreshCalendarData()
                    }
                }
            }
            .navigationTitle("Kiddush Sponsorship")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Clear old cache to get fresh Parsha data with new parsing
                let cacheVersion = UserDefaults.standard.integer(forKey: "hebrew_cache_version")
                if cacheVersion < 3 {
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
            }
            .onDisappear {
                firestoreManager.stopListeningToSponsorships()
            }
            .onChange(of: currentMonth) { _, _ in
                loadCalendarData()
            }
            .onChange(of: firestoreManager.kiddushSponsorships) { _, _ in
                // Force UI refresh when sponsorships change
                refreshTrigger = UUID()
            }
            .sheet(isPresented: $showingSponsorshipForm, onDismiss: {
                // Force refresh when form is dismissed
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
        
        Task {
            // Fetch Shabbat times for this month
            await hebrewCalendarService.fetchShabbatTimes(for: year, month: month)
            
            // Fetch Hebrew dates for visible days
            for date in getDaysInMonth().compactMap({ $0 }) {
                if hebrewDatesCache[date] == nil {
                    if let hebrewDate = await hebrewCalendarService.fetchHebrewDate(for: date) {
                        hebrewDatesCache[date] = hebrewDate
                    }
                }
            }
        }
    }
    
    func previousMonth() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    func nextMonth() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    func goToToday() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentMonth = Date()
        }
    }
    
    func refreshCalendarData() async {
        isRefreshing = true
        
        // Clear cache and reload
        hebrewCalendarService.clearCache()
        CalendarCacheManager.shared.clearCache()
        
        // Preload 90 days
        await hebrewCalendarService.preload90Days()
        
        // Reload current month data
        loadCalendarData()
        
        // Force UI refresh
        refreshTrigger = UUID()
        
        isRefreshing = false
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
    let isPast: Bool
    
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
    
    var body: some View {
        VStack(spacing: 1) {
            // User sponsorship badge
            if isSponsoredByCurrentUser {
                HStack {
                    Spacer()
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                        .padding(2)
                }
            }
            
            // Gregorian Date
            Text("\(dayNumber)")
                .font(.system(size: 18, weight: isToday ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isCurrentMonth ? .primary : Color.secondary.opacity(0.3))
                .padding(.top, isSponsoredByCurrentUser ? 0 : 2)
            
            // Hebrew Date (full date without year)
            if let hebrewDate = hebrewDate, isCurrentMonth {
                Text(hebrewDate)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(height: 16)
            }
            
            // Parsha name for Shabbat
            if isShabbat, isCurrentMonth, let shabbatTime = shabbatTime, let parsha = shabbatTime.parsha {
                Text(parsha)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 2)
            }
            
            // Candle lighting time
            if let shabbatTime = shabbatTime, isCurrentMonth {
                Text(formatTime(shabbatTime.candleLighting))
                    .font(.system(size: 7, design: .rounded))
                    .foregroundStyle(.orange)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cellBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
        )
        .opacity(isCurrentMonth ? (isPast ? 0.5 : 1.0) : 0.3)
    }
    
    var cellBackgroundColor: Color {
        // User's own sponsorships get gold/yellow tint
        if isSponsoredByCurrentUser {
            return .yellow.opacity(0.3)
        }
        // Other sponsored dates get red tint
        else if let _ = sponsorship {
            return .red.opacity(0.25)
        }
        // Shabbat dates
        else if isShabbat && isCurrentMonth {
            // Past dates are grayed out
            if isPast {
                return .gray.opacity(0.15)
            }
            return .blue.opacity(0.1)
        }
        return .clear
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


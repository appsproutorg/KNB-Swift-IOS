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
    @State private var showingDayDetail = false
    @State private var showingSponsorshipForm = false
    @State private var hebrewDatesCache: [Date: String] = [:]
    @State private var refreshTrigger = UUID()  // Force refresh when needed
    @AppStorage("calendarBookingCoachmarkLastShownAt") private var bookingCoachmarkLastShownAt: Double = 0
    @State private var showBookingCoachmark = false
    @State private var bookingCoachmarkPulse = false
    @State private var isLoadingOccasions = false
    
    let calendar = Calendar.chicago
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private var recentUpcomingOccasions: [CommunityOccasionItem] {
        firestoreManager.communityOccasions
            .filter { $0.group == .timeSensitive && $0.isInPriorityWindow }
            .sorted {
                if let lhsDate = $0.effectiveDateIso, let rhsDate = $1.effectiveDateIso, lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                if $0.sortRank != $1.sortRank {
                    return $0.sortRank < $1.sortRank
                }
                return $0.rawText < $1.rawText
            }
    }

    private var celebrationOccasions: [CommunityOccasionItem] {
        firestoreManager.communityOccasions
            .filter { $0.group == .celebration }
            .sorted {
                if $0.sortRank != $1.sortRank {
                    return $0.sortRank < $1.sortRank
                }
                return $0.rawText < $1.rawText
            }
    }

    private var communityNoticeOccasions: [CommunityOccasionItem] {
        firestoreManager.communityOccasions
            .filter { $0.group == .notice }
            .sorted {
                if $0.sortRank != $1.sortRank {
                    return $0.sortRank < $1.sortRank
                }
                return $0.rawText < $1.rawText
            }
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
                
                VStack(spacing: 0) {
                    // Custom Animated Header
                    VStack(spacing: 4) {
                        // Title with gradient
                        Text("Calendar & Kiddush")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.18), radius: 4, x: 0, y: 2)

                        ZStack {
                            if showBookingCoachmark {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.blue)

                                    Text("Tap a Shabbos to reserve Kiddush")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.12))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: .blue.opacity(0.16), radius: 8, x: 0, y: 3)
                                .opacity(showBookingCoachmark ? (bookingCoachmarkPulse ? 1 : 0.8) : 0)
                                .offset(x: showBookingCoachmark ? 0 : -10)
                                .animation(.easeInOut(duration: 0.25), value: showBookingCoachmark)
                                .allowsHitTesting(false)
                            }
                        }
                        .frame(height: showBookingCoachmark ? 34 : 0)
                        
                        // Month/Year with navigation - now more compact
                        HStack(spacing: 10) {
                            Button(action: previousMonth) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.blue.opacity(0.8))
                            }
                            
                            Text(dateFormatter.string(from: currentMonth))
                                .font(.system(size: 23, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentMonth)
                            
                            Button(action: nextMonth) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.blue.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 2)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                        
                        HStack(spacing: 4) {
                            ForEach(Array(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].enumerated()), id: \.offset) { index, day in
                                Text(day)
                                    .font(.system(size: index == 6 ? 15 : 13, weight: index == 6 ? .bold : .semibold, design: .rounded))
                                    .foregroundStyle(index == 6 ? .blue : .secondary)
                                    .frame(maxWidth: index == 6 ? .infinity : 45)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)

                        LazyVGrid(
                            columns: [
                                GridItem(.fixed(45), spacing: 4),
                                GridItem(.fixed(45), spacing: 4),
                                GridItem(.fixed(45), spacing: 4),
                                GridItem(.fixed(45), spacing: 4),
                                GridItem(.fixed(45), spacing: 4),
                                GridItem(.fixed(45), spacing: 4),
                                GridItem(.flexible(), spacing: 4),
                            ],
                            spacing: 8
                        ) {
                            ForEach(Array(getDaysInMonth().enumerated()), id: \.offset) { index, date in
                                if let date = date {
                                    let shabbatTime = hebrewCalendarService.getShabbatTime(for: date)
                                    let sponsorship = firestoreManager.getSponsorship(for: date)
                                    let isShabbat = hebrewCalendarService.isShabbat(date)
                                    let dailyCalendarDay = firestoreManager.getDailyCalendarDay(for: date)
                                    
                                    CalendarDayCell(
                                        date: date,
                                        hebrewDate: hebrewDatesCache[date],
                                        shabbatTime: shabbatTime,
                                        sponsorship: sponsorship,
                                        dailyCalendarDay: dailyCalendarDay,
                                        isShabbat: isShabbat,
                                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                                        currentUserEmail: currentUser?.email,
                                        isPastDate: calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
                                    )
                                    .onTapGesture {
                                        if calendar.isDate(date, equalTo: currentMonth, toGranularity: .month) {
                                            selectedDate = date
                                            if isShabbat {
                                                showingSponsorshipForm = true
                                            } else {
                                                showingDayDetail = true
                                            }
                                        }
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 65)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .id(refreshTrigger)  // Force grid refresh when sponsorships change
                        
                        HappyOccasionsCardView(
                            recentUpcoming: recentUpcomingOccasions,
                            celebrations: celebrationOccasions,
                            communityNotices: communityNoticeOccasions,
                            isLoading: isLoadingOccasions
                        )
                        .padding(.horizontal)
                    }
                    .refreshable {
                        await refreshCalendarFeeds()
                    }
                }
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
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
                    await firestoreManager.prefetchDailyCalendarDefaultWindow()
                }
                loadCalendarData()
                firestoreManager.startListeningToSponsorships()
                firestoreManager.startListeningToCommunityOccasions()
                maybeShowBookingCoachmark()
                isLoadingOccasions = firestoreManager.communityOccasions.isEmpty

                Task {
                    await refreshCalendarFeeds()
                }
                
                print("📊 Current sponsorships count: \(firestoreManager.kiddushSponsorships.count)")
            }
            .onDisappear {
                firestoreManager.stopListeningToSponsorships()
                firestoreManager.stopListeningToCommunityOccasions()
            }
            .onChange(of: currentMonth) { _, _ in
                loadCalendarData()
            }
            .onChange(of: firestoreManager.kiddushSponsorships) { _, newSponsorships in
                // Force UI refresh when sponsorships change
                print("🔄 Sponsorships updated! Count: \(newSponsorships.count)")
                refreshTrigger = UUID()  // This triggers a re-render
            }
            .onChange(of: firestoreManager.communityOccasions) { _, _ in
                if isLoadingOccasions {
                    isLoadingOccasions = false
                }
            }
            .sheet(isPresented: $showingDayDetail) {
                if let date = selectedDate {
                    CalendarDayDetailView(
                        date: date,
                        dailyCalendarDay: firestoreManager.getDailyCalendarDay(for: date),
                        hebrewDate: hebrewDatesCache[date],
                        shabbatTime: hebrewCalendarService.getShabbatTime(for: date),
                        sponsorship: firestoreManager.getSponsorship(for: date),
                        isShabbat: hebrewCalendarService.isShabbat(date),
                        isPastDate: calendar.startOfDay(for: date) < calendar.startOfDay(for: Date()),
                        currentUserEmail: currentUser?.email,
                        isAdminViewer: currentUser?.isAdmin == true,
                        onReserveKiddush: {}
                    )
                    .presentationDetents([.fraction(0.58), .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
                }
            }
            .sheet(isPresented: $showingSponsorshipForm, onDismiss: {
                // Force refresh when form is dismissed
                print("🔄 Form dismissed, forcing calendar refresh")
                Task {
                    // Reload sponsorships from Firestore
                    await firestoreManager.fetchKiddushSponsorships()
                    await firestoreManager.fetchDailyCalendarWindow(centerMonth: currentMonth)
                    // Force UI refresh
                    refreshTrigger = UUID()
                }
            }) {
                if let date = selectedDate {
                    SponsorshipFormView(
                        shabbatDate: date,
                        shabbatTime: hebrewCalendarService.getShabbatTime(for: date),
                        dailyCalendarDay: firestoreManager.getDailyCalendarDay(for: date),
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
        while days.count % 7 != 0 {
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
            await firestoreManager.fetchDailyCalendarWindow(centerMonth: currentMonth)
            
            print("🔍 Checking what shabbatTimes we have:")
            for (date, time) in hebrewCalendarService.shabbatTimes {
                print("   📅 \(date): parsha='\(time.parsha ?? "NONE")'")
            }
            
            print("🔍 Checking sponsorships:")
            for sponsorship in firestoreManager.kiddushSponsorships {
                let startOfDay = calendar.startOfDay(for: sponsorship.date)
                print("   💰 \(startOfDay) - \(sponsorship.sponsorEmail)")
            }
            
            // Fetch Hebrew dates for visible days concurrently.
            let missingDates = getDaysInMonth().compactMap { $0 }.filter { hebrewDatesCache[$0] == nil }
            await withTaskGroup(of: (Date, String?).self) { group in
                for date in missingDates {
                    group.addTask {
                        let hebrewDate = await hebrewCalendarService.fetchHebrewDate(for: date)
                        return (date, hebrewDate)
                    }
                }

                for await (date, hebrewDate) in group {
                    if let hebrewDate {
                        hebrewDatesCache[date] = hebrewDate
                    }
                }
            }

            trimHebrewDatesCache()
            
            print("✅ Calendar data loaded. ShabbatTimes count: \(hebrewCalendarService.shabbatTimes.count)")
        }
    }

    func maybeShowBookingCoachmark() {
        bookingCoachmarkPulse = false

        let now = Date().timeIntervalSince1970
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        guard now - bookingCoachmarkLastShownAt >= sevenDays else {
            return
        }

        bookingCoachmarkLastShownAt = now

        withAnimation(.easeOut(duration: 0.3)) {
            showBookingCoachmark = true
        }
        withAnimation(.easeInOut(duration: 1.0).repeatCount(6, autoreverses: true)) {
            bookingCoachmarkPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            withAnimation(.easeOut(duration: 0.35)) {
                showBookingCoachmark = false
                bookingCoachmarkPulse = false
            }
        }
    }

    func refreshCalendarFeeds() async {
        await MainActor.run {
            isLoadingOccasions = true
        }
        await firestoreManager.fetchCommunityOccasions()
        await firestoreManager.fetchDailyCalendarWindow(centerMonth: currentMonth)
        await MainActor.run {
            isLoadingOccasions = false
        }
    }

    private func trimHebrewDatesCache() {
        let maxCacheEntries = 240
        guard hebrewDatesCache.count > maxCacheEntries else { return }

        let retainedMonths = [-1, 0, 1].compactMap {
            calendar.date(byAdding: .month, value: $0, to: currentMonth)
        }.map {
            calendar.dateComponents([.year, .month], from: $0)
        }

        hebrewDatesCache = hebrewDatesCache.filter { date, _ in
            let components = calendar.dateComponents([.year, .month], from: date)
            return retainedMonths.contains(components)
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
    let dailyCalendarDay: DailyCalendarDay?
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

    var dailyEventBadgeCount: Int {
        let events = dailyCalendarDay?.events.count ?? 0
        let scheduleCount = (dailyCalendarDay?.scheduleLines.isEmpty == false) ? 1 : 0
        return events + scheduleCount
    }
    
    var body: some View {
        VStack(spacing: isShabbat ? 4 : 2) {
            if sponsorship != nil || (isPastDate && isShabbat) || (isCurrentMonth && !isShabbat && dailyEventBadgeCount > 0) {
                HStack {
                    if isCurrentMonth && !isShabbat && dailyEventBadgeCount > 0 {
                        Label("\(dailyEventBadgeCount)", systemImage: "calendar.badge.clock")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if sponsorship != nil {
                        Circle()
                            .fill(Color(red: 0.9, green: 0.2, blue: 0.2))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.6), lineWidth: 2)
                            )
                            .shadow(color: Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.3), radius: 3, x: 0, y: 1)
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
            
            // Hebrew Date - show on all dates if in current month, more prominent on Shabbat
            if let hebrewDate = hebrewDate, isCurrentMonth {
                Text(hebrewDate)
                    .font(.system(size: isShabbat ? 11 : 7, weight: isShabbat ? .medium : .regular, design: .rounded))
                    .foregroundStyle(isPastDate ? Color.secondary.opacity(0.4) : (isShabbat ? .primary : .secondary))
                    .lineLimit(1)
                    .padding(.horizontal, isShabbat ? 4 : 2)
                    .padding(.top, 2)
            }
            
            // Shabbat-specific details
            if isShabbat, isCurrentMonth {
                // Parsha name - no bubble, scales down if too long
                if let shabbatTime = shabbatTime, let parsha = shabbatTime.parsha {
                    Text(parsha)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            isPastDate ? 
                            Color.secondary.opacity(0.5) : 
                            (sponsorship != nil ? 
                             Color(red: 0.9, green: 0.2, blue: 0.2) : 
                             (isAvailableForSponsorship ? Color(red: 0.2, green: 0.6, blue: 0.3) : .blue))
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }
            
            Spacer(minLength: 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isShabbat ? 90 : 70)
        .background(cellBackgroundMaterial)
        .overlay(cellOverlay)
        .opacity(isCurrentMonth ? (isPastDate ? 0.5 : 1.0) : 0.25)
        .scaleEffect(isToday ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isToday)
        .shadow(color: (sponsorship != nil ? Color(red: 0.9, green: 0.2, blue: 0.2) : (isShabbat && isAvailableForSponsorship && !isPastDate ? Color(red: 0.2, green: 0.6, blue: 0.3) : (isShabbat && !isPastDate ? .blue : .clear))).opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    // Modern box backgrounds with status colors
    @ViewBuilder
    var cellBackgroundMaterial: some View {
        ZStack {
            // Base background - modern rounded box
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // Status-based color overlay with gradients
            if let _ = sponsorship {
                // Sponsored - red (already booked) with gradient
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.2),
                                Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if isShabbat && isAvailableForSponsorship && isCurrentMonth {
                // Available Shabbat - green (can book) with gradient
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.6, blue: 0.3).opacity(0.15),
                                Color(red: 0.15, green: 0.5, blue: 0.25).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if isPastDate && isShabbat {
                // Past Shabbat - gray (locked)
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.08))
            } else if isCurrentMonth && !isShabbat {
                // Regular days - light blue tint
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.05))
            }
        }
    }
    
    // Modern box borders with gradients
    @ViewBuilder
    var cellOverlay: some View {
        if isToday {
            // Today gets a prominent blue border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.blue, lineWidth: 3)
                .shadow(color: .blue.opacity(0.4), radius: 4, x: 0, y: 2)
        } else if sponsorship != nil {
            // Sponsored dates get red gradient border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.8),
                            Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        } else if isShabbat && isAvailableForSponsorship && isCurrentMonth {
            // Available Shabbats get green gradient border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.6, blue: 0.3).opacity(0.6),
                            Color(red: 0.15, green: 0.5, blue: 0.25).opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        } else if isCurrentMonth {
            // Regular dates get subtle border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.clear, lineWidth: 0)
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CalendarDayDetailView: View {
    let date: Date
    let dailyCalendarDay: DailyCalendarDay?
    let hebrewDate: String?
    let shabbatTime: ShabbatTime?
    let sponsorship: KiddushSponsorship?
    let isShabbat: Bool
    let isPastDate: Bool
    let currentUserEmail: String?
    let isAdminViewer: Bool
    let onReserveKiddush: () -> Void

    private var displayDateText: String {
        DateFormatter.detailDateFormatter.string(from: date)
    }

    private var displayHebrewDate: String {
        let source = dailyCalendarDay?.hebrewDate ?? hebrewDate ?? ""
        let cleaned = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "—" : cleaned
    }

    private var canReserveKiddush: Bool {
        isShabbat && !isPastDate && sponsorship == nil
    }

    private var isSponsoredByCurrentUser: Bool {
        guard let sponsorship, let currentUserEmail else { return false }
        return sponsorship.sponsorEmail == currentUserEmail
    }

    private var sponsorDisplayName: String {
        guard let sponsorship else { return "Reserved" }
        if sponsorship.isAnonymous && !isAdminViewer && !isSponsoredByCurrentUser {
            return "Anonymous Sponsor"
        }
        return sponsorship.sponsorName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayDateText)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                        Text(displayHebrewDate)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )

                    if isShabbat {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shabbat")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            if let parsha = shabbatTime?.parsha, !parsha.isEmpty {
                                Text("Parsha: \(parsha)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            if let shabbatTime {
                                Text("Candle Lighting: \(formatTime(shabbatTime.candleLighting))")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                Text("Havdalah: \(formatTime(shabbatTime.havdalah))")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.08))
                        )
                    }

                    if let sponsorship {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kiddush Sponsorship")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("Sponsored By: \(sponsorDisplayName)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text(sponsorship.occasion)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red.opacity(0.08))
                        )
                    }

                    if canReserveKiddush {
                        Button(action: onReserveKiddush) {
                            Label("Reserve Kiddush", systemImage: "calendar.badge.plus")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }

                    if let dailyCalendarDay, !dailyCalendarDay.scheduleLines.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Schedule")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            ForEach(Array(dailyCalendarDay.scheduleLines.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 10) {
                                    if let timeText = line.timeText, !timeText.isEmpty {
                                        Text(timeText)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 74, alignment: .leading)
                                    }
                                    Text(line.title)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    if let dailyCalendarDay, dailyCalendarDay.zmanim.hasAnyValue {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Zmanim")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            ZmanRow(title: "Alos", value: dailyCalendarDay.zmanim.alos)
                            ZmanRow(title: "Netz", value: dailyCalendarDay.zmanim.netz)
                            ZmanRow(title: "Chatzos", value: dailyCalendarDay.zmanim.chatzos)
                            ZmanRow(title: "Shkia", value: dailyCalendarDay.zmanim.shkia)
                            ZmanRow(title: "Tzes", value: dailyCalendarDay.zmanim.tzes)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    if let dailyCalendarDay, !dailyCalendarDay.events.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Events")
                                .font(.system(size: 15, weight: .bold, design: .rounded))

                            ForEach(dailyCalendarDay.events) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.categoryLabel.uppercased())
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Text(event.title)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    if let details = event.detailsText, !details.isEmpty {
                                        Text(details)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.62))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatTime(_ date: Date) -> String {
        DateFormatter.detailTimeFormatter.string(from: date)
    }
}

private struct ZmanRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension DateFormatter {
    static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    static let detailTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

#Preview {
    CalendarView(
        firestoreManager: FirestoreManager(),
        currentUser: .constant(User(name: "John Doe", email: "john@example.com", totalPledged: 0))
    )
}

// MARK: - Happy Occasions Components
struct HappyOccasionsCardView: View {
    let recentUpcoming: [CommunityOccasionItem]
    let celebrations: [CommunityOccasionItem]
    let communityNotices: [CommunityOccasionItem]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Community Occasions")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Clear categories and cleaner event text")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading latest occasions...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                HappyOccasionsSectionView(
                    title: "Recent & Upcoming",
                    subtitle: "Birthdays, anniversaries, and yahrzeit in the active window.",
                    items: recentUpcoming,
                    emptyText: "No birthdays, anniversaries, or yahrzeit entries in the current window."
                )

                HappyOccasionsSectionView(
                    title: "Celebrations",
                    subtitle: "Engagements, births, and bar/bas mitzvah announcements.",
                    items: celebrations,
                    emptyText: "No celebration entries available right now."
                )

                HappyOccasionsSectionView(
                    title: "Community Notices",
                    subtitle: "Important notices and community updates.",
                    items: communityNotices,
                    emptyText: "No community notices right now."
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.secondary.opacity(0.18), Color.secondary.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

struct HappyOccasionsSectionView: View {
    let title: String
    let subtitle: String
    let items: [CommunityOccasionItem]
    let emptyText: String
    @State private var isExpanded = true

    private var categoryGroups: [OccasionCategoryGroup] {
        var grouped: [CommunityOccasionCategory: [CommunityOccasionItem]] = [:]
        var orderedCategories: [CommunityOccasionCategory] = []

        for item in items {
            if grouped[item.category] == nil {
                orderedCategories.append(item.category)
            }
            grouped[item.category, default: []].append(item)
        }

        return orderedCategories.compactMap { category in
            guard let groupedItems = grouped[category] else { return nil }
            return OccasionCategoryGroup(category: category, items: groupedItems)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    if !items.isEmpty {
                        Text("\(items.count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if items.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(categoryGroups) { group in
                        OccasionCategoryGroupView(group: group)
                    }
                }
            }
        }
    }
}

private struct OccasionCategoryGroupView: View {
    let group: OccasionCategoryGroup

    private var style: OccasionCategoryStyle {
        group.category.occasionStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(style.iconBackground)
                    Image(systemName: group.category.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(style.accent)
                }
                .frame(width: 26, height: 26)

                Text(group.category.displayLabel.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(style.accent)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(group.items.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(style.accent.opacity(0.9))
            }

            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                CommunityOccasionRow(item: item, style: style)
                if index < group.items.count - 1 {
                    Divider()
                        .overlay(style.rowBorder.opacity(0.4))
                        .padding(.leading, 2)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CommunityOccasionRow: View {
    let item: CommunityOccasionItem
    let style: OccasionCategoryStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.preferredDisplayText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if item.showsStandaloneDateBadge, let dateText = item.displayDateText, !dateText.isEmpty {
                Label(dateText, systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(style.accent.opacity(0.95))
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OccasionCategoryGroup: Identifiable {
    let category: CommunityOccasionCategory
    let items: [CommunityOccasionItem]

    var id: String {
        category.rawValue
    }
}

private struct OccasionCategoryStyle {
    let accent: Color
    let sectionBackground: Color
    let sectionBorder: Color
    let rowBorder: Color
    let badgeBackground: Color
    let iconBackground: Color
}

private extension CommunityOccasionCategory {
    var occasionStyle: OccasionCategoryStyle {
        switch self {
        case .birthdays:
            return OccasionCategoryStyle(
                accent: Color(red: 0.11, green: 0.47, blue: 0.89),
                sectionBackground: Color(red: 0.92, green: 0.96, blue: 1.0),
                sectionBorder: Color(red: 0.74, green: 0.87, blue: 1.0),
                rowBorder: Color(red: 0.73, green: 0.86, blue: 0.99),
                badgeBackground: Color(red: 0.84, green: 0.92, blue: 1.0),
                iconBackground: Color(red: 0.82, green: 0.91, blue: 1.0)
            )
        case .yahrzeit:
            return OccasionCategoryStyle(
                accent: Color(red: 0.66, green: 0.42, blue: 0.08),
                sectionBackground: Color(red: 1.0, green: 0.96, blue: 0.89),
                sectionBorder: Color(red: 0.95, green: 0.84, blue: 0.62),
                rowBorder: Color(red: 0.94, green: 0.83, blue: 0.61),
                badgeBackground: Color(red: 0.98, green: 0.9, blue: 0.72),
                iconBackground: Color(red: 0.97, green: 0.88, blue: 0.69)
            )
        case .engagements:
            return OccasionCategoryStyle(
                accent: Color(red: 0.68, green: 0.22, blue: 0.62),
                sectionBackground: Color(red: 0.99, green: 0.93, blue: 0.98),
                sectionBorder: Color(red: 0.93, green: 0.77, blue: 0.91),
                rowBorder: Color(red: 0.92, green: 0.76, blue: 0.9),
                badgeBackground: Color(red: 0.96, green: 0.84, blue: 0.95),
                iconBackground: Color(red: 0.95, green: 0.81, blue: 0.93)
            )
        case .births:
            return OccasionCategoryStyle(
                accent: Color(red: 0.02, green: 0.56, blue: 0.28),
                sectionBackground: Color(red: 0.92, green: 0.98, blue: 0.92),
                sectionBorder: Color(red: 0.74, green: 0.9, blue: 0.75),
                rowBorder: Color(red: 0.72, green: 0.89, blue: 0.74),
                badgeBackground: Color(red: 0.84, green: 0.95, blue: 0.85),
                iconBackground: Color(red: 0.8, green: 0.93, blue: 0.81)
            )
        case .barBasMitzvahs:
            return OccasionCategoryStyle(
                accent: Color(red: 0.29, green: 0.39, blue: 0.87),
                sectionBackground: Color(red: 0.93, green: 0.94, blue: 1.0),
                sectionBorder: Color(red: 0.79, green: 0.82, blue: 0.99),
                rowBorder: Color(red: 0.78, green: 0.81, blue: 0.99),
                badgeBackground: Color(red: 0.85, green: 0.88, blue: 1.0),
                iconBackground: Color(red: 0.83, green: 0.86, blue: 0.99)
            )
        case .anniversaries:
            return OccasionCategoryStyle(
                accent: Color(red: 0.71, green: 0.24, blue: 0.53),
                sectionBackground: Color(red: 1.0, green: 0.94, blue: 0.98),
                sectionBorder: Color(red: 0.95, green: 0.79, blue: 0.9),
                rowBorder: Color(red: 0.94, green: 0.78, blue: 0.89),
                badgeBackground: Color(red: 0.97, green: 0.86, blue: 0.93),
                iconBackground: Color(red: 0.96, green: 0.84, blue: 0.92)
            )
        case .condolences:
            return OccasionCategoryStyle(
                accent: Color(red: 0.89, green: 0.47, blue: 0.13),
                sectionBackground: Color(red: 1.0, green: 0.96, blue: 0.91),
                sectionBorder: Color(red: 0.97, green: 0.84, blue: 0.66),
                rowBorder: Color(red: 0.96, green: 0.83, blue: 0.64),
                badgeBackground: Color(red: 0.99, green: 0.9, blue: 0.76),
                iconBackground: Color(red: 0.99, green: 0.88, blue: 0.72)
            )
        }
    }
}

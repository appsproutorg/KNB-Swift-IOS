//
//  CalendarCacheManager.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import Foundation

class CalendarCacheManager {
    static let shared = CalendarCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let cacheVersionKey = "calendar_cache_version"
    private let cacheVersion = 1
    private let cacheDateKey = "calendar_cache_date"
    private let hebrewDatesKey = "calendar_hebrew_dates"
    private let shabbatTimesKey = "calendar_shabbat_times"
    
    // Cache expires after 7 days
    private let cacheExpirationDays = 7
    
    private init() {}
    
    // MARK: - Cache Status
    
    func isCacheValid() -> Bool {
        // Check if cache exists and is not expired
        guard let cacheDate = userDefaults.object(forKey: cacheDateKey) as? Date else {
            return false
        }
        
        let daysSinceCached = Calendar.current.dateComponents([.day], from: cacheDate, to: Date()).day ?? 0
        return daysSinceCached < cacheExpirationDays
    }
    
    // MARK: - Hebrew Dates Cache
    
    func cacheHebrewDate(_ hebrewDate: String, for date: Date) {
        var hebrewDates = getHebrewDatesCache()
        let key = dateKey(for: date)
        hebrewDates[key] = hebrewDate
        
        if let data = try? JSONEncoder().encode(hebrewDates) {
            userDefaults.set(data, forKey: hebrewDatesKey)
        }
    }
    
    func getHebrewDate(for date: Date) -> String? {
        let hebrewDates = getHebrewDatesCache()
        let key = dateKey(for: date)
        return hebrewDates[key]
    }
    
    private func getHebrewDatesCache() -> [String: String] {
        guard let data = userDefaults.data(forKey: hebrewDatesKey),
              let hebrewDates = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return hebrewDates
    }
    
    // MARK: - Shabbat Times Cache
    
    func cacheShabbatTime(_ shabbatTime: ShabbatTime, for date: Date) {
        var shabbatTimes = getShabbatTimesCache()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let key = dateKey(for: startOfDay)
        shabbatTimes[key] = shabbatTime
        
        print("💾 Caching ShabbatTime for \(startOfDay), parsha: '\(shabbatTime.parsha ?? "none")'")
        
        if let data = try? JSONEncoder().encode(shabbatTimes) {
            userDefaults.set(data, forKey: shabbatTimesKey)
        }
    }
    
    func getShabbatTime(for date: Date) -> ShabbatTime? {
        let shabbatTimes = getShabbatTimesCache()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let key = dateKey(for: startOfDay)
        return shabbatTimes[key]
    }
    
    private func getShabbatTimesCache() -> [String: ShabbatTime] {
        guard let data = userDefaults.data(forKey: shabbatTimesKey),
              let shabbatTimes = try? JSONDecoder().decode([String: ShabbatTime].self, from: data) else {
            return [:]
        }
        return shabbatTimes
    }
    
    // MARK: - Batch Operations
    
    func cacheHebrewDates(_ dates: [Date: String]) {
        var hebrewDates = getHebrewDatesCache()
        for (date, hebrewDate) in dates {
            let key = dateKey(for: date)
            hebrewDates[key] = hebrewDate
        }
        
        if let data = try? JSONEncoder().encode(hebrewDates) {
            userDefaults.set(data, forKey: hebrewDatesKey)
        }
    }
    
    func cacheShabbatTimes(_ times: [Date: ShabbatTime]) {
        var shabbatTimes = getShabbatTimesCache()
        let calendar = Calendar.current
        
        for (date, shabbatTime) in times {
            let startOfDay = calendar.startOfDay(for: date)
            let key = dateKey(for: startOfDay)
            shabbatTimes[key] = shabbatTime
            print("💾 Batch caching ShabbatTime for \(startOfDay), parsha: '\(shabbatTime.parsha ?? "none")'")
        }
        
        if let data = try? JSONEncoder().encode(shabbatTimes) {
            userDefaults.set(data, forKey: shabbatTimesKey)
        }
    }
    
    // MARK: - Cache Management
    
    func updateCacheDate() {
        userDefaults.set(Date(), forKey: cacheDateKey)
        userDefaults.set(cacheVersion, forKey: cacheVersionKey)
    }
    
    func clearCache() {
        userDefaults.removeObject(forKey: hebrewDatesKey)
        userDefaults.removeObject(forKey: shabbatTimesKey)
        userDefaults.removeObject(forKey: cacheDateKey)
        userDefaults.removeObject(forKey: cacheVersionKey)
    }
    
    func getCachedDateRange() -> (start: Date, end: Date)? {
        let hebrewDates = getHebrewDatesCache()
        guard !hebrewDates.isEmpty else { return nil }
        
        let dates = hebrewDates.keys.compactMap { dateFromKey($0) }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            return nil
        }
        
        return (minDate, maxDate)
    }
    
    // MARK: - Helper Methods
    
    private func dateKey(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
    
    private func dateFromKey(_ key: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: key)
    }
    
    // MARK: - 90-Day Preload Support
    
    func get90DayRange() -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in 0..<90 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    func needsPreload() -> Bool {
        guard isCacheValid() else { return true }
        
        // Check if we have data for the next 90 days
        let requiredDates = get90DayRange()
        let hebrewDates = getHebrewDatesCache()
        
        let cachedCount = requiredDates.filter { date in
            let key = dateKey(for: date)
            return hebrewDates[key] != nil
        }.count
        
        // If less than 80% cached, preload
        return Double(cachedCount) / Double(requiredDates.count) < 0.8
    }
}


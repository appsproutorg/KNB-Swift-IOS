//
//  HebrewCalendarService.swift
//  KNB
//
//  Created by AI Assistant on 11/11/25.
//

import Foundation
import Combine

@MainActor
class HebrewCalendarService: ObservableObject {
    @Published var shabbatTimes: [Date: ShabbatTime] = [:]
    @Published var hebrewDates: [Date: String] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://www.hebcal.com"
    private var cache: [String: Any] = [:]
    private let cacheManager = CalendarCacheManager.shared
    
    // MARK: - 90-Day Preload
    func preload90Days() async {
        // Check if we need to preload
        guard cacheManager.needsPreload() else {
            print("✅ Cache is valid, skipping preload")
            loadFromCache()
            return
        }
        
        print("📥 Preloading 90 days of calendar data...")
        let dates = cacheManager.get90DayRange()
        
        // Batch fetch Hebrew dates
        for date in dates {
            if cacheManager.getHebrewDate(for: date) == nil {
                if let hebrewDate = await fetchHebrewDateFromAPI(for: date) {
                    cacheManager.cacheHebrewDate(hebrewDate, for: date)
                    hebrewDates[date] = hebrewDate
                }
                // Add small delay to avoid overwhelming API
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } else {
                // Load from cache
                if let cached = cacheManager.getHebrewDate(for: date) {
                    hebrewDates[date] = cached
                }
            }
        }
        
        // Fetch Shabbat times for next 3 months
        let calendar = Calendar.current
        let today = Date()
        for monthOffset in 0..<3 {
            if let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                let components = calendar.dateComponents([.year, .month], from: targetMonth)
                if let year = components.year, let month = components.month {
                    await fetchShabbatTimes(for: year, month: month)
                }
            }
        }
        
        cacheManager.updateCacheDate()
        print("✅ Preload complete!")
    }
    
    private func loadFromCache() {
        // Load cached data into memory
        let dates = cacheManager.get90DayRange()
        for date in dates {
            if let hebrewDate = cacheManager.getHebrewDate(for: date) {
                hebrewDates[date] = hebrewDate
            }
            if let shabbatTime = cacheManager.getShabbatTime(for: date) {
                shabbatTimes[date] = shabbatTime
            }
        }
    }
    
    // MARK: - Fetch Shabbat Times for Chicago
    func fetchShabbatTimes(for year: Int, month: Int) async {
        isLoading = true
        errorMessage = nil
        
        let cacheKey = "shabbat_\(year)_\(month)"
        
        // Check cache first
        if let cached = cache[cacheKey] as? [Date: ShabbatTime] {
            self.shabbatTimes.merge(cached) { _, new in new }
            isLoading = false
            return
        }
        
        // Build URL for Shabbat times - use hebcal.com/hebcal API for full month data
        var components = URLComponents(string: "\(baseURL)/hebcal")
        components?.queryItems = [
            URLQueryItem(name: "v", value: "1"),
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "maj", value: "on"),  // Major holidays
            URLQueryItem(name: "min", value: "on"),  // Minor holidays  
            URLQueryItem(name: "mod", value: "on"),  // Modern holidays
            URLQueryItem(name: "nx", value: "on"),   // Rosh Chodesh
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "month", value: "\(month)"),
            URLQueryItem(name: "ss", value: "on"),   // Sunrise/sunset
            URLQueryItem(name: "mf", value: "on"),   // Candle lighting
            URLQueryItem(name: "c", value: "on"),    // Include candle lighting
            URLQueryItem(name: "geo", value: "city"),
            URLQueryItem(name: "city", value: "Chicago"),
            URLQueryItem(name: "M", value: "on"),    // Include Torah reading
            URLQueryItem(name: "s", value: "on")     // Include weekly sedra/parsha
        ]
        
        print("🌐 Fetching from URL: \(components?.url?.absoluteString ?? "invalid")")
        
        guard let url = components?.url else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Debug: Print raw JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 Hebcal API Raw Response for \(year)-\(month):")
                print(jsonString.prefix(500))  // First 500 chars
            }
            
            let response = try JSONDecoder().decode(HebcalShabbatResponse.self, from: data)
            print("📊 Hebcal returned \(response.items.count) items")
            
            var monthTimes: [Date: ShabbatTime] = [:]
            var currentCandles: Date?
            var currentDate: Date?
            var currentParsha: String?
            
            for (index, item) in response.items.enumerated() {
                print("   Item \(index): category='\(item.category)', title='\(item.title)'")
                
                if item.category == "candles" {
                    currentCandles = item.date
                    currentDate = item.date
                    print("      🕯️ Found candles for \(item.date)")
                } else if item.category == "parashat" || item.title.starts(with: "Parashat ") {
                    // Store parsha - check both category and title pattern
                    currentParsha = item.title.replacingOccurrences(of: "Parashat ", with: "")
                    print("      📖 Found parsha: '\(currentParsha ?? "")'")
                } else if item.category == "havdalah" {
                    if let candles = currentCandles, let date = currentDate {
                        // CRITICAL: Use startOfDay as key for consistent matching
                        let calendar = Calendar.current
                        let startOfDay = calendar.startOfDay(for: date)
                        
                        let shabbatTime = ShabbatTime(
                            date: startOfDay,
                            candleLighting: candles,
                            havdalah: item.date,
                            parsha: currentParsha
                        )
                        monthTimes[startOfDay] = shabbatTime
                        print("      ✅ Created ShabbatTime with parsha: '\(currentParsha ?? "NONE")' for \(startOfDay)")
                    } else {
                        print("      ⚠️ Havdalah found but missing candles/date!")
                    }
                    currentCandles = nil
                    currentDate = nil
                    currentParsha = nil
                }
            }
            
            print("📋 Total ShabbatTimes created: \(monthTimes.count)")
            for (date, time) in monthTimes {
                print("   📅 \(date): parsha='\(time.parsha ?? "NONE")'")
            }
            
            self.shabbatTimes.merge(monthTimes) { _, new in new }
            cache[cacheKey] = monthTimes
            
            // Cache to CalendarCacheManager
            cacheManager.cacheShabbatTimes(monthTimes)
            
        } catch {
            errorMessage = "Failed to fetch Shabbat times: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch Hebrew Date
    func fetchHebrewDate(for gregorianDate: Date) async -> String? {
        // Check cache first
        if let cached = cacheManager.getHebrewDate(for: gregorianDate) {
            hebrewDates[gregorianDate] = cached
            return cached
        }
        
        // Fetch from API
        return await fetchHebrewDateFromAPI(for: gregorianDate)
    }
    
    private func fetchHebrewDateFromAPI(for gregorianDate: Date) async -> String? {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: gregorianDate)
        
        guard let year = dateComponents.year,
              let month = dateComponents.month,
              let day = dateComponents.day else {
            return nil
        }
        
        let cacheKey = "hebrew_\(year)_\(month)_\(day)"
        
        // Check cache first
        if let cached = cache[cacheKey] as? String {
            return cached
        }
        
        // Build URL for Hebrew date conversion
        var urlComponents = URLComponents(string: "\(baseURL)/converter")
        urlComponents?.queryItems = [
            URLQueryItem(name: "cfg", value: "json"),
            URLQueryItem(name: "gy", value: "\(year)"),
            URLQueryItem(name: "gm", value: "\(month)"),
            URLQueryItem(name: "gd", value: "\(day)"),
            URLQueryItem(name: "g2h", value: "1")
        ]
        
        guard let url = urlComponents?.url else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(HebcalConverterResponse.self, from: data)
            
            let hebrewDateString = response.hebrew
            
            // Remove the year from the Hebrew date (e.g., "15 Cheshvan 5785" -> "15 Cheshvan")
            let hebrewDateWithoutYear = removeYearFromHebrewDate(hebrewDateString)
            
            cache[cacheKey] = hebrewDateWithoutYear
            hebrewDates[gregorianDate] = hebrewDateWithoutYear
            
            // Cache to CalendarCacheManager
            cacheManager.cacheHebrewDate(hebrewDateWithoutYear, for: gregorianDate)
            
            return hebrewDateWithoutYear
        } catch {
            print("Failed to fetch Hebrew date: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Get Shabbat for Date
    func getShabbatTime(for date: Date) -> ShabbatTime? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return shabbatTimes[startOfDay]
    }
    
    // MARK: - Check if Date is Shabbat
    func isShabbat(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 7  // Saturday
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        cache.removeAll()
        shabbatTimes.removeAll()
        hebrewDates.removeAll()
    }
    
    // MARK: - Helper Methods
    
    // Remove year from Hebrew date string (e.g., "15 Cheshvan 5785" -> "15 Cheshvan")
    private func removeYearFromHebrewDate(_ hebrewDate: String) -> String {
        let components = hebrewDate.components(separatedBy: " ")
        // Hebrew dates typically have 3 components: day, month, year
        // Keep only the first two (day and month)
        if components.count >= 3 {
            return components[0] + " " + components[1]
        }
        return hebrewDate
    }
}

// MARK: - Hebcal API Response Models

struct HebcalShabbatResponse: Codable {
    let items: [HebcalItem]
}

struct HebcalItem: Codable {
    let title: String
    let date: Date
    let category: String
    let hebrew: String?
    let hdate: String?
    
    enum CodingKeys: String, CodingKey {
        case title, date, hebrew, hdate
        case category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        
        // Category might be missing or have different name
        category = (try? container.decode(String.self, forKey: .category)) ?? ""
        
        hebrew = try container.decodeIfPresent(String.self, forKey: .hebrew)
        hdate = try container.decodeIfPresent(String.self, forKey: .hdate)
        
        // Parse the date string - could be ISO8601 or simple date
        let dateString = try container.decode(String.self, forKey: .date)
        
        // Try ISO8601 first
        let iso8601Formatter = ISO8601DateFormatter()
        if let parsedDate = iso8601Formatter.date(from: dateString) {
            date = parsedDate
        } else {
            // Try simple date format: "YYYY-MM-DD"
            let simpleDateFormatter = DateFormatter()
            simpleDateFormatter.dateFormat = "yyyy-MM-dd"
            simpleDateFormatter.timeZone = TimeZone(identifier: "America/Chicago")
            if let parsedDate = simpleDateFormatter.date(from: dateString) {
                date = parsedDate
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .date,
                    in: container,
                    debugDescription: "Date string '\(dateString)' does not match expected formats"
                )
            }
        }
    }
}

struct HebcalConverterResponse: Codable {
    let hebrew: String
    let hy: Int
    let hm: String
    let hd: Int
}


//
//  Extensions.swift
//  KNB
//
//  Created by Ethan Goizman on 10/21/25.
//

import Foundation

// MARK: - Chicago Timezone Calendar
extension Calendar {
    /// Shared calendar configured to Chicago timezone (America/Chicago)
    /// This ensures all users see the same Shabbat dates regardless of their device timezone
    static var chicago: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }
}

// MARK: - Safe Double to Int Conversion
extension Double {
    func toSafeInt() -> Int {
        if self.isNaN || self.isInfinite {
            return 0
        }
        if self > Double(Int.max) {
            return Int.max
        }
        if self < Double(Int.min) {
            return Int.min
        }
        return Int(self)
    }
}


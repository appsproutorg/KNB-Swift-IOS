import Foundation

/// Cache manager for user data to avoid redundant Firestore queries
/// Implements in-memory caching with automatic expiration
@MainActor
class UserCacheManager {
    static let shared = UserCacheManager()
    
    private struct CachedUser {
        let name: String
        let timestamp: Date
    }
    
    private var cache: [String: CachedUser] = [:]
    private let cacheLifetime: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    /// Get user name from cache or return nil if not cached/expired
    func getCachedName(for email: String) -> String? {
        guard let cached = cache[email] else { return nil }
        
        // Check if cache is expired
        if Date().timeIntervalSince(cached.timestamp) > cacheLifetime {
            cache.removeValue(forKey: email)
            return nil
        }
        
        return cached.name
    }
    
    /// Cache a user's name
    func cacheName(_ name: String, for email: String) {
        cache[email] = CachedUser(name: name, timestamp: Date())
    }
    
    /// Clear all cached data
    func clearCache() {
        cache.removeAll()
    }
    
    /// Update cached name when user changes their name
    func updateCachedName(_ newName: String, for email: String) {
        cache[email] = CachedUser(name: newName, timestamp: Date())
    }
}

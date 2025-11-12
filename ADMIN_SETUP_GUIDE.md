# Admin Access Implementation Guide

## Quick Setup (Current Method)

### Enable Admin-Only Debug Menu

1. **Open `MainTabView.swift`** (line 20)
   ```swift
   // Change from:
   return true
   
   // To:
   return currentUser?.hasAdminAccess == true
   ```

2. **Add Admin Emails in `AuthenticationManager.swift`** (lines 100-104)
   ```swift
   private func isAdminEmail(_ email: String) -> Bool {
       let adminEmails = [
           "appsproutorg@gmail.com",
           "admin@knb.com"
           // Add more admin emails here
       ]
       return adminEmails.contains(email.lowercased())
   }
   ```

3. **Log out and log back in** to refresh user data

---

## Enhanced Implementation (Firestore-Based)

For production apps, it's better to store admin status in Firestore for:
- ✅ Better security (can't be extracted from app binary)
- ✅ Dynamic updates (no app rebuild needed)
- ✅ Audit trail
- ✅ More admin properties (roles, permissions, etc.)

### Step 1: Create Firestore Collection

In your Firebase Console:

1. Go to **Firestore Database**
2. Create a new collection called `admin_users`
3. Add documents with user emails as document IDs:

```
admin_users/
  └── appsproutorg@gmail.com
      ├── email: "appsproutorg@gmail.com"
      ├── role: "super_admin"
      ├── permissions: ["reset_bids", "delete_data", "view_logs"]
      └── created_at: timestamp
```

### Step 2: Update FirestoreManager.swift

Add this function to check admin status:

```swift
// MARK: - Admin Functions

// Check if a user is an admin
func checkAdminStatus(email: String) async -> Bool {
    do {
        let doc = try await db.collection("admin_users")
            .document(email.lowercased())
            .getDocument()
        
        return doc.exists
    } catch {
        print("Error checking admin status: \(error.localizedDescription)")
        return false
    }
}

// Get admin permissions
func getAdminPermissions(email: String) async -> [String] {
    do {
        let doc = try await db.collection("admin_users")
            .document(email.lowercased())
            .getDocument()
        
        if let permissions = doc.data()?["permissions"] as? [String] {
            return permissions
        }
    } catch {
        print("Error fetching admin permissions: \(error.localizedDescription)")
    }
    return []
}
```

### Step 3: Update AuthenticationManager.swift

Replace the `loadUserData` function:

```swift
private func loadUserData(from firebaseUser: FirebaseAuth.User) async {
    let email = firebaseUser.email ?? ""
    
    // Check admin status from Firestore
    let firestoreManager = FirestoreManager()
    let isAdmin = await firestoreManager.checkAdminStatus(email: email)
    
    user = User(
        name: firebaseUser.displayName ?? "Member",
        email: email,
        totalPledged: 0,
        isAdmin: isAdmin
    )
    isAuthenticated = true
}
```

And update the function calls to be async:

```swift
// In checkAuthState()
func checkAuthState() {
    guard !hasCheckedAuth else { return }
    hasCheckedAuth = true
    
    if let firebaseUser = Auth.auth().currentUser {
        Task {
            await loadUserData(from: firebaseUser)
        }
    }
}

// In signIn()
func signIn(email: String, password: String) async -> Bool {
    do {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        await loadUserData(from: authResult.user)
        errorMessage = nil
        return true
    } catch {
        errorMessage = error.localizedDescription
        return false
    }
}
```

### Step 4: Set Up Firestore Security Rules

Protect your admin collection:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Admin users collection - read-only for authenticated users
    match /admin_users/{email} {
      // Users can check if they are admin
      allow read: if request.auth != null && request.auth.token.email == email;
      
      // Only existing admins can create/update admin users
      allow write: if request.auth != null && 
                      exists(/databases/$(database)/documents/admin_users/$(request.auth.token.email));
    }
    
    // Honors collection
    match /honors/{honorId} {
      allow read: if true; // Anyone can read
      allow create: if isAdmin(); // Only admins can create
      allow update: if request.auth != null; // Authenticated users can bid
      allow delete: if isAdmin(); // Only admins can delete
    }
    
    // Helper function to check admin status
    function isAdmin() {
      return request.auth != null && 
             exists(/databases/$(database)/documents/admin_users/$(request.auth.token.email));
    }
  }
}
```

### Step 5: Add Your First Admin Manually

**Option A: Firebase Console**
1. Go to Firestore Database
2. Create collection `admin_users`
3. Add document with ID: `appsproutorg@gmail.com`
4. Add fields:
   - `email`: `appsproutorg@gmail.com`
   - `role`: `super_admin`
   - `created_at`: (timestamp - now)

**Option B: Using Firebase CLI**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Run this script
firebase firestore:import admin_users.json
```

---

## Admin Roles & Permissions (Advanced)

### Define Different Admin Levels

```swift
enum AdminRole: String, Codable {
    case superAdmin = "super_admin"    // Full access
    case moderator = "moderator"       // Can reset bids, view data
    case viewer = "viewer"             // Can only view debug info
}

struct AdminUser: Codable {
    let email: String
    let role: AdminRole
    let permissions: [String]
    let createdAt: Date
}
```

### Update User Model

```swift
struct User: Codable, Equatable {
    var name: String
    var email: String
    var totalPledged: Double
    var isAdmin: Bool = false
    var adminRole: AdminRole? = nil
    
    // Check specific permissions
    func hasPermission(_ permission: String) -> Bool {
        return isAdmin // For now, all admins have all permissions
    }
    
    var hasAdminAccess: Bool {
        return isAdmin
    }
}
```

### Conditional Debug Menu Features

Update `DebugMenuView.swift` to show different options based on role:

```swift
// Only show dangerous actions to super admins
if currentUser?.adminRole == .superAdmin {
    DebugButton(
        title: "Reset All Honors",
        icon: "trash.circle.fill",
        color: .red,
        isProcessing: isProcessing
    ) {
        showingResetHonorsConfirmation = true
    }
}

// Show to all admins
if currentUser?.isAdmin == true {
    DebugButton(
        title: "Reset All Bids",
        icon: "arrow.counterclockwise.circle.fill",
        color: .orange,
        isProcessing: isProcessing
    ) {
        showingResetBidsConfirmation = true
    }
}
```

---

## Testing Admin Access

### Test Checklist

- [ ] Admin user sees debug menu
- [ ] Non-admin user doesn't see debug menu
- [ ] Admin can reset bids successfully
- [ ] Admin can delete sponsorships
- [ ] Non-admin cannot access admin functions (even if they know the endpoint)
- [ ] Admin status persists across app restarts
- [ ] Logging out removes admin access

### Test Users Setup

Create these test accounts:

1. **Super Admin**: `appsproutorg@gmail.com`
2. **Regular User**: `testuser@example.com`
3. **Moderator**: `mod@example.com`

---

## Security Best Practices

### ⚠️ Important Security Notes

1. **Don't rely on client-side checks alone**
   - Always validate admin status on the server (Firestore Rules)
   - Client-side checks (like hiding the UI) are for UX, not security

2. **Use Firestore Security Rules**
   - Prevent non-admins from accessing admin functions
   - Even if they decompile your app

3. **Audit Logging**
   - Log all admin actions to a `admin_logs` collection
   - Track who did what and when

4. **Remove debug code in production**
   - Consider using build configurations:
   ```swift
   #if DEBUG
   private var showDebugMenu: Bool { return true }
   #else
   private var showDebugMenu: Bool { return currentUser?.hasAdminAccess == true }
   #endif
   ```

---

## Troubleshooting

**Q: Debug menu doesn't appear for admin user**
- Log out and log back in
- Check that email matches exactly (case-insensitive)
- Verify Firestore document exists

**Q: Non-admin can still see debug menu**
- Check that you changed `return true` to `return currentUser?.hasAdminAccess == true`
- Make sure you're testing with a non-admin email

**Q: Can't add new admins**
- Check Firestore Security Rules
- Ensure you're logged in as an existing admin
- Use Firebase Console to manually add the first admin

---

## Quick Reference

```swift
// Check if current user is admin
if currentUser?.hasAdminAccess == true {
    // Show admin features
}

// Check specific permission
if currentUser?.hasPermission("reset_bids") == true {
    // Allow reset
}

// Get admin role
if currentUser?.adminRole == .superAdmin {
    // Super admin only features
}
```


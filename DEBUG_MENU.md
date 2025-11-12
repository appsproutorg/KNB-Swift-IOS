# Debug Menu Documentation

## Overview
The KNB app now includes a debug menu at the bottom of the screen for testing and data management purposes.

## Features

### Current Capabilities
1. **Reset All Bids** - Clears all bids and resets all honors to $0 (keeps honor structure intact)
2. **Reset All Honors** - Completely deletes and re-initializes all honors to default state
3. **Delete All Sponsorships** - Removes all Kiddush sponsorships from the database
4. **Debug Info Panel** - Shows real-time statistics:
   - Total Honors count
   - Total Sponsorships count
   - Active Bids count

### How to Use

#### Accessing the Debug Menu
- Look for the "Debug Menu" button at the bottom of the screen
- Tap to expand the menu
- Tap again (or tap the chevron) to collapse it

#### Using Debug Functions
1. Tap on any debug action button (Reset All Bids, etc.)
2. Confirm the action in the alert dialog
3. Wait for the success confirmation
4. The UI will automatically update with the new data

## Admin Access Control

### Current State (Development)
The debug menu is **currently visible to all users** for testing purposes.

### Restricting to Admin Users (Production)

To restrict the debug menu to admin users only:

1. **Update MainTabView.swift** (line 19-20):
   ```swift
   // Change from:
   return true // TODO: Change to: currentUser?.hasAdminAccess == true
   
   // To:
   return currentUser?.hasAdminAccess == true
   ```

2. **Set Admin Emails** in `AuthenticationManager.swift` (lines 100-104):
   ```swift
   private func isAdminEmail(_ email: String) -> Bool {
       let adminEmails = [
           "appsproutorg@gmail.com", // Your admin email
           "admin@example.com"       // Add more admin emails here
       ]
       return adminEmails.contains(email.lowercased())
   }
   ```

### Making Someone an Admin

**Current Method (Hardcoded):**
1. Add their email to the `adminEmails` array in `AuthenticationManager.swift`
2. Rebuild and deploy the app

**Recommended Future Method:**
Store admin flags in Firestore for better security and flexibility:
- Create an `admin_users` collection in Firestore
- Check admin status when loading user data
- Allows dynamic admin management without app updates

## Security Considerations

⚠️ **IMPORTANT**: Before releasing to production:

1. **Hide the debug menu** by changing `showDebugMenu` to check `currentUser?.hasAdminAccess == true`
2. **Protect admin endpoints** - Consider adding Firestore security rules that only allow admins to perform destructive operations
3. **Move admin list to Firestore** - Don't hardcode admin emails in the app (they can be extracted from the binary)
4. **Add audit logging** - Track who performs admin actions and when

## Firebase Security Rules Example

```javascript
// Firestore Security Rules for Honors Collection
match /honors/{honorId} {
  // Anyone can read
  allow read: if true;
  
  // Only admins can delete or reset
  allow delete: if isAdmin();
  
  // Users can update (place bids)
  allow update: if request.auth != null;
}

function isAdmin() {
  return request.auth != null && 
         exists(/databases/$(database)/documents/admin_users/$(request.auth.uid));
}
```

## Future Enhancements

Consider adding:
- [ ] View all users
- [ ] Manual bid entry/editing
- [ ] Export data to CSV
- [ ] Auction start/stop controls
- [ ] Push notification controls
- [ ] View activity logs
- [ ] Rollback functionality

## Troubleshooting

**Debug menu not appearing:**
- Check that `showDebugMenu` returns `true` in `MainTabView.swift`
- Verify you're logged in

**Actions not working:**
- Check Firestore permissions
- Review console logs for error messages
- Ensure network connectivity

**Admin access not working:**
- Verify your email is in the `adminEmails` array
- Log out and log back in to refresh user data
- Check spelling/capitalization of email addresses


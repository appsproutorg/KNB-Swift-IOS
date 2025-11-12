# Firestore Backend Setup for KNB App

## Overview
This document explains how to properly configure Firebase Firestore to handle Kiddush sponsorships in the KNB app.

## Collections Structure

### 1. `kiddush_sponsorships` Collection

This collection stores all Kiddush sponsorship records.

**Document Structure:**
```json
{
  "id": "UUID-string",
  "date": Timestamp,           // Stored as startOfDay (no time component)
  "sponsorName": "String",
  "sponsorEmail": "String",
  "occasion": "String",
  "isAnonymous": Boolean,
  "timestamp": Timestamp,       // When sponsorship was created
  "isPaid": Boolean
}
```

### 2. `available_shabbat_dates` Collection (Optional - Admin Control)

This collection is optional and allows admin control over which dates are available for sponsorship.

**Document Structure:**
```json
{
  "date": Timestamp,
  "isAvailable": Boolean,
  "notes": "String (optional)"
}
```

If this collection is empty, the app automatically makes all future Saturdays available.

## Required Firestore Indexes

### Composite Index for `kiddush_sponsorships`

You need a composite index to support date range queries.

**Index Configuration:**
- **Collection:** `kiddush_sponsorships`
- **Fields to index:**
  1. `date` - Ascending
  2. `__name__` - Ascending (Document ID)
- **Query Scope:** Collection

**How to Create:**

1. Go to Firebase Console → Firestore Database
2. Click on "Indexes" tab
3. Click "Create Index"
4. Enter the above configuration
5. Click "Create"

**Alternative (Automatic):** When you first try to sponsor a Shabbat, Firestore may show an error with a direct link to create the required index. Click that link and the index will be created automatically.

### Index for User Sponsorships Query

**Index Configuration:**
- **Collection:** `kiddush_sponsorships`
- **Fields to index:**
  1. `sponsorEmail` - Ascending
  2. `date` - Descending (for sorting newest first)
- **Query Scope:** Collection

## Security Rules

Add these security rules to protect your Firestore data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Honors collection - read-only for authenticated users
    match /honors/{honorId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // You may want to restrict this to admins
    }
    
    // Kiddush Sponsorships - authenticated users can read and create
    match /kiddush_sponsorships/{sponsorshipId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null 
                    && request.resource.data.sponsorEmail == request.auth.token.email;
      allow update, delete: if false; // Only allow through admin console
    }
    
    // Available Shabbat Dates - read by all authenticated users
    match /available_shabbat_dates/{dateId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only through console
    }
  }
}
```

## Testing the Setup

### 1. Clean Up Test Data

If you have test sponsorships with incorrect date formats:

1. Open the app
2. Go to Calendar tab
3. Tap the small trash icon (top right corner)
4. This will delete all test sponsorships

### 2. Test Sponsorship Flow

1. **Open Calendar tab**
2. **Select a future Shabbat** (Saturday)
3. **Fill in the form:**
   - Name (auto-filled)
   - Email (auto-filled)
   - Occasion (e.g., "Birthday")
   - Check/uncheck "Sponsor Anonymously"
4. **Submit**

**Expected Results:**
- ✅ Sponsorship should save successfully
- ✅ Calendar should show green checkmark on that date
- ✅ Profile tab should show the sponsorship in history
- ✅ Same date cannot be sponsored again

### 3. Check Console Logs

When testing, watch Xcode console for these messages:

```
🔍 Checking sponsorship for date: [date]
📊 Found 0 existing sponsorships for this date
✅ Creating sponsorship for [date]
🎉 Sponsorship created successfully
```

If you see:
```
❌ Date already sponsored
```
This means either:
1. Someone already sponsored that date (check your Profile tab), OR
2. There's old test data (use the trash button to clean up)

### 4. Verify in Firebase Console

1. Go to Firebase Console → Firestore Database
2. Navigate to `kiddush_sponsorships` collection
3. Look for your sponsorship document
4. Check that the `date` field is a **Timestamp** at midnight (00:00:00)

## Common Issues & Solutions

### Issue: "Already Sponsored" Error on Empty Dates

**Cause:** Old test data with timestamps that don't match current date format.

**Solution:**
1. Use the trash button in Calendar tab to clean up
2. Or manually delete from Firebase Console

### Issue: "Missing Index" Error

**Cause:** Required Firestore indexes not created.

**Solution:**
1. Click the link in the error message to create the index automatically
2. Or manually create the indexes as described above

### Issue: Hebrew Dates Showing Years

**Cause:** Cached data from before the year-removal update.

**Solution:**
1. Delete and reinstall the app to clear cache, OR
2. The cache will auto-refresh after 7 days

### Issue: Parsha Not Showing

**Cause:** Hebcal API didn't return Parsha data for that week.

**Solution:**
- Check if the date is actually a Shabbat
- Some weeks may not have a regular weekly Parsha (e.g., holidays)
- Try a different Shabbat

## Data Migration

If you need to migrate existing data:

1. **Export existing data** from Firebase Console
2. **Update date fields** to use `startOfDay` format
3. **Re-import** the cleaned data

## Admin Management

To manage sponsorships as an admin:

1. Go to Firebase Console → Firestore Database
2. Navigate to `kiddush_sponsorships`
3. You can:
   - View all sponsorships
   - Update `isPaid` status
   - Delete sponsorships if needed
   - Export data for records

## Backup & Recovery

**Recommended:**
1. Enable Firestore automatic backups in Firebase Console
2. Export sponsorship data monthly for records
3. Keep records of payments outside of Firestore

## Support

If you encounter issues:
1. Check console logs for detailed error messages
2. Verify indexes are created
3. Check security rules allow the operation
4. Ensure dates are stored as `startOfDay` timestamps


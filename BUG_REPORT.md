# KNB App — Full Bug & Issue Report

> **Generated:** February 22, 2026
> **Scope:** Cloud Functions (`functions/index.js`), iOS Swift App (`KNB/`), Firestore Rules, Storage Rules, Configuration Files

---

## Table of Contents

1. [Summary Dashboard](#summary-dashboard)
2. [Critical Issues](#critical-issues)
3. [High Severity Issues](#high-severity-issues)
4. [Medium Severity Issues](#medium-severity-issues)
5. [Low Severity Issues](#low-severity-issues)

---

## Summary Dashboard

| Severity | Count |
|----------|-------|
| **Critical** | 12 |
| **High** | 17 |
| **Medium** | 16 |
| **Low** | 12 |
| **Total** | **57** |

| Category | Count |
|----------|-------|
| Security | 10 |
| Bugs / Logic Errors | 14 |
| Data Integrity | 11 |
| Performance | 7 |
| Error Handling | 5 |
| Code Quality | 6 |
| Configuration | 4 |

---

## Critical Issues

### C-01: Privilege Escalation — Any User Can Make Themselves Admin

**Area:** Firestore Rules → `users` collection
**File:** `firestore.rules` (lines 161–162)

The `users` create rule only validates `email == request.auth.token.email`. It does **not** enforce `isAdmin == false`. A malicious client bypassing the Swift app can create their user document with `isAdmin: true`, granting full admin access to all collections.

```
allow create: if isAuthenticated() 
              && request.resource.data.email == request.auth.token.email;
```

**Impact:** Complete admin takeover of the app.

**Fix:** Add `&& request.resource.data.isAdmin == false` to the create rule, or:
```
&& (!('isAdmin' in request.resource.data.keys()) || request.resource.data.isAdmin == false)
```

---

### C-02: Buy Now Is Completely Broken for Non-Admin Users

**Area:** Firestore Rules vs. iOS Client
**Files:** `firestore.rules` (line 85), `FirestoreManager.swift` (`buyNow()`)

`buyNow()` writes four fields: `bids`, `currentBid`, `currentWinner`, and `isSold`. The honor update rule for non-admins restricts writes to `hasOnly(['bids', 'currentBid', 'currentWinner'])`. Since `isSold` is not in the allowed set, **every Buy Now attempt by a regular user is silently rejected by Firestore**.

**Impact:** Core feature completely non-functional for all non-admin users.

**Fix:** Either:
- Add `'isSold'` to the allowed keys with validation (`request.resource.data.isSold == true`)
- Move Buy Now logic to a Cloud Function

---

### C-03: `fetchUserData` Overwrites Current Logged-In User

**Area:** iOS App — Data Corruption
**Files:** `PostCard.swift`, `FirestoreManager.swift` (line ~1731)

`PostCard.loadAuthorName()` calls `firestoreManager.fetchUserData(email: post.authorEmail)` as a fallback. But `fetchUserData` unconditionally sets `self.currentUser = user`, **overwriting the logged-in user's data** with the post author's data. This changes the current user identity mid-session.

**Impact:** After viewing a post by another user, the app may behave as if the viewer is that other user.

**Fix:** Split into two methods: `fetchUserData(email:)` (sets `currentUser`) and `fetchUser(email:) -> User?` (returns without side effects).

---

### C-04: Double Notification on Reply Likes

**Area:** Cloud Functions
**File:** `functions/index.js` (lines 135–168 & 204–240)

Both `onPostLikeUpdate` and `onReplyLikeUpdate` trigger on `social_posts/{id}` updates. When a reply gets a like, **both** functions fire:
- `onPostLikeUpdate` has no check for `parentPostId`, sending a `POST_LIKE` notification
- `onReplyLikeUpdate` checks `parentPostId` and sends a `REPLY_LIKE` notification

The reply author receives **two notifications** for every single like.

**Impact:** Duplicate push notifications for every reply like.

**Fix:** Add early return in `onPostLikeUpdate`:
```javascript
if (after.parentPostId) return; // Replies handled by onReplyLikeUpdate
```

---

### C-05: FCM Token Cleanup Deletes Valid Tokens on Transient Errors

**Area:** Cloud Functions
**File:** `functions/index.js` (lines 76–88)

Every failed FCM token is deleted regardless of error type. Transient errors (quota exceeded, internal server error, unavailable) incorrectly remove valid tokens, **permanently breaking push notifications** for that device.

**Impact:** Users silently stop receiving push notifications after any temporary FCM outage.

**Fix:** Only delete on terminal errors:
```javascript
if (errorCode === 'messaging/invalid-registration-token' ||
    errorCode === 'messaging/registration-token-not-registered') {
    // Only then delete the token
}
```

---

### C-06: Null Crash on `post.content` and `reply.content`

**Area:** Cloud Functions
**File:** `functions/index.js` (lines 117, 195)

If `content` is `null`, `undefined`, or missing, both `onAdminPostCreate` and `onPostReplyCreate` throw `TypeError: Cannot read properties of undefined`. These trigger functions have **no try/catch**, crashing the entire invocation and potentially causing infinite retries.

**Impact:** Server crash + potential infinite retry loop.

**Fix:** Use `(post.content || "").substring(0, 50)` and wrap in try/catch.

---

### C-07: Firestore Batch 500-Operation Limit Exceeded

**Area:** Cloud Functions + iOS App
**Files:** `functions/index.js` (`onUserUpdate`), `FirestoreManager.swift` (`deleteSocialPost`)

A single `WriteBatch` is used for all operations. Firestore limits batches to 500 operations. A prolific user with 500+ combined posts/replies will cause the batch to fail.

**Impact:** Name propagation and post deletion silently fail for active users.

**Fix:** Chunk operations into batches of 499.

---

### C-08: Race Condition in `toggleLike` — No Transaction

**Area:** iOS App
**File:** `FirestoreManager.swift` (`toggleLike`)

The like operation does a read-then-write without a Firestore transaction. Two simultaneous likes can desync the `likes` array and `likeCount`, or lose entries.

**Impact:** Like counts become incorrect; likes can be lost.

**Fix:** Wrap the read + update in `db.runTransaction`.

---

### C-09: Splash Screen Auth Race Condition

**Area:** iOS App
**Files:** `ContentView.swift` (lines 33–54), `AuthenticationManager.swift`

`authManager.checkAuthState()` spawns an unstructured `Task` for Firestore fetch. The check `if authManager.isAuthenticated` runs *before* that Task completes, so returning users briefly see the login screen.

**Impact:** Poor UX — authenticated users flash through login screen.

**Fix:** Make `checkAuthState()` async and `await` the Firestore fetch.

---

### C-10: Seat IDs Are Non-Deterministic UUIDs

**Area:** iOS App
**File:** `SeatingView.swift`

Each `Seat` gets `id: UUID().uuidString`. When `generateSeatData()` re-runs (e.g., on reappear), all seats get new IDs. `selectedSeats: Set<String>` stores these IDs, so selected seats can never be found again.

**Impact:** Seat selection breaks after any view lifecycle event.

**Fix:** Use deterministic IDs like `"\(row)-\(number)"`.

---

### C-11: `totalPledged` Increment Is Not Atomic

**Area:** iOS App
**File:** `HonorDetailView.swift`

The local total is read, incremented locally, and written as an absolute value. Two quick bids (or two devices) causes the second write to overwrite the first.

**Impact:** User pledge totals become incorrect.

**Fix:** Use `FieldValue.increment(Int64(amount))`.

---

### C-12: Exposed SendGrid API Key

**Area:** Configuration
**File:** `functions/.env`

The `.env` file contains a real SendGrid API key in plain text. While `.gitignore` includes `functions/.env`, the key is now exposed.

**Impact:** If the repo was ever pushed before `.gitignore` was set, the key is in git history.

**Fix:** **Rotate the SendGrid API key immediately.** Consider using Firebase Secret Manager (`defineSecret()`).

---

## High Severity Issues

### H-01: Deleting Top-Level Post Fails to Delete Other Users' Replies

**Area:** Firestore Rules vs. iOS Client
**Files:** `firestore.rules` (lines 138–140), `FirestoreManager.swift` (`deleteSocialPost`)

When a non-admin deletes their own post, the code tries to batch-delete all reply documents. Replies by **other users** are rejected by rules (`authorEmail == request.auth.token.email`), leaving orphaned replies in Firestore.

**Fix:** Move cascading deletes to a Cloud Function triggered on post deletion.

---

### H-02: Any User Can Manipulate Anyone's Likes

**Area:** Firestore Rules
**File:** `firestore.rules` (lines 131–136)

The update rule doesn't validate that the authenticated user is only adding/removing **their own** email from the `likes` array. A malicious client can add fake likes, remove others' likes, or set `likeCount` to any non-negative value.

**Fix:** Validate that the likes diff is exactly the requesting user's email, and `likeCount == likes.size()`.

---

### H-03: `replyCount` Freely Manipulable

**Area:** Firestore Rules
**File:** `firestore.rules`

Any authenticated user can set any post's `replyCount` to any non-negative value without actually adding/removing replies.

**Fix:** Only allow `replyCount` changes via Cloud Functions, or validate increment by exactly 1.

---

### H-04: `authorName` Not Validated — Impersonation Possible

**Area:** Firestore Rules → `social_posts`

The create rule validates `authorEmail` but not `authorName`. A malicious client can create posts displaying any name while using their own email.

**Fix:** Cross-reference `authorName` against the user's profile, or resolve it server-side.

---

### H-05: No Try/Catch in 5 Firestore Trigger Functions

**Area:** Cloud Functions
**File:** `functions/index.js`

`onAdminPostCreate`, `onPostLikeUpdate`, `onPostReplyCreate`, `onReplyLikeUpdate`, and `onOutbid` have zero error handling. Any exception causes unhandled rejection and potential infinite retries.

**Fix:** Wrap each trigger body in try/catch with proper logging.

---

### H-06: Race Condition on Sponsorship Delete

**Area:** Cloud Functions
**File:** `functions/index.js` (`onKiddushSponsorshipDelete`)

Read-then-write without a transaction. The periodic sync could overwrite the document between the read and write.

**Fix:** Use a Firestore transaction.

---

### H-07: No Idempotency Guards on Notification Triggers

**Area:** Cloud Functions

Cloud Functions can retry on failure. Without idempotency, retries send duplicate notifications. Only `onKiddushSponsorshipCreate` has a guard (`bookingEmailSentAt`).

**Fix:** Use `context.eventId` against a deduplication store.

---

### H-08: FCM `data` Payload Values Must Be Strings

**Area:** Cloud Functions
**File:** `functions/index.js` (line 49)

FCM requires all `data` map values to be strings. If any caller passes a number, `sendEachForMulticast` rejects the message.

**Fix:** `data: Object.fromEntries(Object.entries(notification.data || {}).map(([k, v]) => [k, String(v)]))`

---

### H-09: Full Collection Scan for Admin Post Notifications

**Area:** Cloud Functions
**File:** `functions/index.js` (line 123)

Every admin post fetches **all user documents**. Each user doc is then individually re-read by `sendNotification`. For N users: `1 + N` reads + `N` writes + `N` FCM sends.

**Fix:** Use FCM topic subscription, or `select()` only needed fields.

---

### H-10: Sequential N+1 Queries in Like Handlers

**Area:** Cloud Functions
**File:** `functions/index.js` (lines 152–167, 225–239)

For each new liker, there's a sequential `await` for Firestore read + notification send.

**Fix:** Use `Promise.all()` or `db.getAll()` to batch.

---

### H-11: Missing `category` Field in Real-Time Honors Listener

**Area:** iOS App
**File:** `FirestoreManager.swift` (`startListening`)

The real-time listener never reads the `category` field, defaulting all honors to "General". The one-time `fetchHonors()` reads it correctly, causing inconsistent behavior.

**Fix:** Add `category` parsing to the listener.

---

### H-12: `stopListening()` Only Stops Honors Listener

**Area:** iOS App
**File:** `FirestoreManager.swift`

The class manages 6 listeners but `stopListening()` only removes the honors listener. The other 5 keep running and holding strong references.

**Fix:** Create `stopAllListeners()` or implement `deinit`.

---

### H-13: Sign-Out Doesn't Clean Up State

**Area:** iOS App
**File:** `AuthenticationManager.swift` (`signOut`)

Sign-out only calls `Auth.auth().signOut()`. It does NOT: remove FCM token from Firestore, clear cached user, stop Firestore listeners, or clear `firestoreManager.currentUser`. The user continues receiving push notifications after sign-out.

**Fix:** Clean up all state on sign-out.

---

### H-14: FCM Token Storage Inconsistency

**Area:** iOS App
**Files:** `AuthenticationManager.swift`, `PushRegistrationManager.swift`

`storeFCMTokenIfAvailable()` writes a flat `fcmToken` field. `syncFCMToken()` writes a nested `fcmTokens` map. Both fields coexist, but backend logic may only read one.

**Fix:** Standardize on the `fcmTokens` map format everywhere.

---

### H-15: No Pagination on Social Posts

**Area:** iOS App
**File:** `FirestoreManager.swift`

Both `startListeningToSocialPosts` and `fetchSocialPosts` fetch **all** posts with no `.limit()`. This will load thousands of posts as the community grows.

**Fix:** Add `.limit(50)` with "load more" pagination.

---

### H-16: `collectionGroup("replies")` May Find Nothing

**Area:** Cloud Functions
**File:** `functions/index.js` (`onUserUpdate`)

The function queries `collectionGroup("replies")` for name propagation, but replies appear to be stored as top-level documents in `social_posts` (not a subcollection). Name changes won't propagate to replies.

**Fix:** Query `social_posts` with `where("parentPostId", "!=", null)` and `where("authorEmail", "==", userEmail)`.

---

### H-17: All User Profiles Readable by Any Authenticated User

**Area:** Firestore Rules
**File:** `firestore.rules` (line 159)

Any logged-in user can read any other user's full profile, including email, FCM tokens, notification preferences, and admin status.

**Fix:** Restrict reads to own document, or create a public-facing profile subcollection.

---

## Medium Severity Issues

### M-01: `DispatchQueue.main.async` Inside `@MainActor` Class

**File:** `FirestoreManager.swift`

The class is `@MainActor`, so `DispatchQueue.main.async` wrappers are redundant and create strong reference cycles (captures `self` without `[weak self]`).

**Fix:** Remove the `DispatchQueue.main.async` wrappers.

---

### M-02: Duplicate `onAppear` and `onChange` Handlers

**File:** `ProfileTabView.swift`

Two `.onAppear` blocks and two `.onChange(of: firestoreManager.currentUser)` blocks on the same `NavigationStack` cause redundant work and potential infinite loops.

**Fix:** Merge into single handlers.

---

### M-03: `loadUserData` Task Can Overwrite Sign-Out

**File:** `AuthenticationManager.swift`

An unstructured `Task` spawned by `loadUserData` could complete after `signOut()`, re-setting `user` and `isAuthenticated = true`.

**Fix:** Store the `Task` handle and cancel it on sign-out.

---

### M-04: `merge: true` Leaves Stale Fields in Calendar Sync

**File:** `functions/index.js`

Sync functions use `set(..., { merge: true })`. Fields from previous sync that are removed in the new payload persist as zombie data.

**Fix:** Use `set()` without `merge` for full replacements.

---

### M-05: O(n²) Like Comparison

**File:** `functions/index.js` (lines 146, 219)

`afterLikes.filter(email => !beforeLikes.includes(email))` is O(n²) for large like arrays.

**Fix:** Use `Set` for O(n) comparison.

---

### M-06: No Input Validation on Sponsorship Document Fields

**File:** `functions/index.js` (`onKiddushSponsorshipCreate`)

Fields from `snap.data()` are used without type or length validation. Malformed documents produce broken emails.

**Fix:** Validate required fields at the top; return early on failure.

---

### M-07: No Rate Limiting on `sendTestNotification`

**File:** `functions/index.js`

Any authenticated user can call this in a tight loop, generating unlimited push notifications.

**Fix:** Enforce a minimum interval between calls.

---

### M-08: Mixed Gen 1 / Gen 2 Firebase Functions API

**File:** `functions/index.js`

Firestore triggers use v1, scheduled functions use v2. Different scaling, timeouts, and pricing apply.

**Fix:** Plan migration to consistent v2 API.

---

### M-09: Hardcoded Super Admin Email in Security Rules

**Files:** `firestore.rules`, `storage.rules`

`admin@knb.com` is hardcoded. If compromised, the attacker has full access and it can't be revoked without redeploying rules.

**Fix:** Use custom claims (`request.auth.token.superAdmin == true`) set server-side.

---

### M-10: Admin Check Triggers Billed Firestore Read

**Files:** `firestore.rules`, `storage.rules`

Every `isAdmin()` call for non-super-admins triggers a `get()` — a billed read on every protected operation.

**Fix:** Use custom claims to eliminate the extra read.

---

### M-11: No `functions.ignore` in `firebase.json`

**File:** `firebase.json`

Without an ignore list, deployment uploads unnecessary files (README, .env.example, etc.).

**Fix:** Add `"ignore"` array.

---

### M-12: Unbounded `hebrewDatesCache` Growth

**File:** `CalendarView.swift`

Cache grows indefinitely as the user navigates months, never evicted.

**Fix:** Limit cache size or clear for non-visible months.

---

### M-13: Sequential Hebrew Date Fetching

**File:** `CalendarView.swift`

Each Hebrew date fetched one-by-one with `await` — 30 sequential requests per month.

**Fix:** Use `withTaskGroup` for concurrent fetching.

---

### M-14: `setupLiquidGlassTabBar` Called Repeatedly

**File:** `MainTabView.swift`

`UITabBar.appearance()` mutations fire on every `onAppear`.

**Fix:** Guard with a static flag for one-time execution.

---

### M-15: `kiddush_sponsorships` Minimal Field Validation

**File:** `firestore.rules`

Only `sponsorEmail` is validated on create. `isPaid` is not enforced `false` — a user could mark their own sponsorship as paid. No `hasOnly` restriction on fields.

**Fix:** Validate field types and enforce `isPaid == false` on creation.

---

### M-16: `users` Update Rule Allows Arbitrary Field Writes

**File:** `firestore.rules`

Self-updates only enforce `email` and `isAdmin` unchanged. A user could set `totalPledged` to any value or inject unexpected fields.

**Fix:** Add `hasOnly` for allowed fields.

---

## Low Severity Issues

### L-01: `LiquidGlassTabBarModifier` Is Dead Code

**File:** `MainTabView.swift`

The struct and extension are defined but never used.

**Fix:** Remove unused code.

---

### L-02: Excessive Debug Logging in Production

**Files:** Multiple Swift files

Extensive `print()` statements with emojis leak user data (emails, sponsorship details) to the console in production.

**Fix:** Use `os_log` or wrap in `#if DEBUG`.

---

### L-03: `SocialPostMediaUpload` Holds Raw Image Data

**File:** `Models.swift`

Up to 4 uploads at several MB each = ~20MB+ held in memory simultaneously.

**Fix:** Compress before storing or use file URLs.

---

### L-04: Timer Leak in `NetworkMonitor`

**File:** `NetworkMonitor.swift`

No `deinit` cleanup — `recheckTimer` and `NWPathMonitor` continue running if deallocated without `stopMonitoring()`.

**Fix:** Add `deinit { stopMonitoring() }`.

---

### L-05: Old FCM Tokens Never Cleaned Up Client-Side

**File:** `PushRegistrationManager.swift`

When a device gets a new FCM token, the old token entry in the `fcmTokens` map is never removed. Stale tokens accumulate.

**Fix:** Remove old token entry when registering a new one.

---

### L-06: Force Unwrap Can Crash

**File:** `FirestoreManager.swift` (line ~938)

```swift
let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
```

**Fix:** Use `guard let`.

---

### L-07: Google Sign-In Cancellation Detection Is Fragile

**File:** `AuthenticationManager.swift`

String matching on localized error description (`message.contains("cancel")`) breaks in non-English locales.

**Fix:** Check `GIDSignInError.Code.canceled`.

---

### L-08: `NotificationManager` Initialized with Empty Email

**File:** `ProfileTabView.swift`

`@StateObject private var notificationManager = NotificationManager(currentUserEmail: "")` — starts in invalid state and may fire listeners with empty email before real one is set.

**Fix:** Initialize lazily or gate listener start on non-empty email.

---

### L-09: Push Permissions Requested Immediately on Launch

**File:** `KNBApp.swift`

System prompt appears on first launch with no context. Users who deny can't easily re-enable.

**Fix:** Defer to a contextual moment (after first post, sponsorship, etc.).

---

### L-10: Orphaned `replies` Index Override

**File:** `firestore.indexes.json`

Field override for `replies` collection, but no such collection exists — replies are in `social_posts`.

**Fix:** Remove the stale index override.

---

### L-11: `.gitignore` Missing Common Patterns

**File:** `.gitignore`

Missing: `*.log` glob, `.firebase/`, `.env.local`, `functions/lib/`.

**Fix:** Add missing patterns.

---

### L-12: Duplicate/Redundant Code

**Files:** `functions/index.js`

- Duplicate comments (lines 170–171, 202–203)
- Identical URL constants (`KIDDUSH_CALENDAR_URL` == `HERITAGE_HOME_URL`)
- Redundant `currentWinner` check (line 257 duplicates line 251)
- `PushRegistrationManager` not `@MainActor` but publishes UI state
- Admin destructive actions have no confirmation dialogs

**Fix:** Clean up duplicates, add confirmation alerts for destructive admin actions.

---

## Priority Fix Order

1. **C-01** — Privilege escalation (security)
2. **C-12** — Rotate SendGrid API key (security)
3. **C-02** — Buy Now broken (feature broken)
4. **C-03** — `fetchUserData` overwrites current user (data corruption)
5. **H-02** — Like manipulation (security)
6. **C-04** — Double notifications (UX)
7. **C-05** — Token cleanup (notifications broken)
8. **C-06** — Null crash in Cloud Functions (stability)
9. **H-13** — Sign-out cleanup (security/UX)
10. **H-01** — Cascading delete fails (data integrity)

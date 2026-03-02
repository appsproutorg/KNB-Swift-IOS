# KNB App Flutter Android Porting Handoff

Last updated: February 26, 2026

## 1) Objective

Port the existing iOS SwiftUI app in this repository to Flutter for Android, while preserving current backend behavior and data compatibility.

Primary goal: keep the same Firebase project, Firestore schema, Cloud Functions triggers, Storage paths, and user-facing features so Android users and iOS users share one backend without breaking notifications, chat, feed, bidding, or calendar flows.

## 2) Current System (Source of Truth)

- Mobile app: SwiftUI (`/Users/ethangoizman/Downloads/Apps/IOS/KNB/KNB`)
- Backend: Firebase project `the-knb-app`
- Cloud Functions: Node 20 (`/Users/ethangoizman/Downloads/Apps/IOS/KNB/functions/index.js`)
- Firestore rules: `/Users/ethangoizman/Downloads/Apps/IOS/KNB/firestore.rules`
- Firestore indexes: `/Users/ethangoizman/Downloads/Apps/IOS/KNB/firestore.indexes.json`
- Storage rules: `/Users/ethangoizman/Downloads/Apps/IOS/KNB/storage.rules`
- Firebase iOS config: `/Users/ethangoizman/Downloads/Apps/IOS/KNB/KNB/GoogleService-Info.plist`

## 3) Features To Port

Implement all of these in Flutter Android:

1. Email/password auth + Google Sign-In
2. User profiles + admin role handling
3. Calendar tab:
- Kiddush calendar (`kiddushCalendar`)
- App sponsorships (`kiddush_sponsorships`)
- Community occasions (`communityOccasions`)
- Daily calendar (`dailyCalendar`)
4. Social feed:
- Top-level posts and replies in `social_posts`
- Likes, reply counts, edit post
- Image uploads (up to 4 images, max 3MB each rule-side)
5. Messaging:
- Rabbi chat (`rabbi_messages`)
- Direct chat (`direct_messages`)
- Chat directory (`chat_directory`)
6. Auction:
- Honors + bidding + buy-now in `honors`
7. Seat reservations (`seat_reservations`)
8. In-app notifications inbox (`users/{email}/notifications`)
9. Push notifications (FCM token registration + deep linking)
10. Siddur text views, including East compass support
11. Network/offline awareness and Firestore offline cache behavior

## 4) Required Flutter Stack

Minimum recommended:

- Flutter stable (latest)
- Dart 3+
- Android min SDK 24+
- Firebase Android SDK via FlutterFire

Packages to use:

- `firebase_core`
- `firebase_auth`
- `google_sign_in`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`
- `cloud_functions`
- `shared_preferences`
- `connectivity_plus`
- `image_picker` (camera/gallery)
- `cached_network_image`
- `flutter_compass` (or equivalent heading plugin)
- `permission_handler`

## 5) Firebase + Android Setup Requirements

1. Use existing Firebase project: `the-knb-app`
2. Add Android app in Firebase Console (new package name for Flutter app)
3. Download `google-services.json` into `android/app/`
4. Enable/verify:
- Authentication: Email/Password + Google
- Firestore
- Storage
- Cloud Functions
- Cloud Messaging
5. SHA fingerprints:
- Register debug and release SHA-1/SHA-256 for Google sign-in
6. Deploy backend artifacts if needed:
- `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`

## 6) Backend Contracts (Must Stay Compatible)

### Firestore Collections Used by App

- `users/{email}`
- `users/{email}/notifications/{notificationId}`
- `honors/{honorId}`
- `kiddush_sponsorships/{sponsorshipId}`
- `kiddushCalendar/{isoDate}`
- `available_shabbat_dates/{dateId}`
- `communityOccasions/{docId}`
- `dailyCalendar/{isoDate}`
- `social_posts/{postId}`
- `rabbi_messages/{messageId}`
- `direct_messages/{messageId}`
- `chat_directory/{email}`
- `seat_reservations/{seatId}`

Private/meta collections used by functions:

- `_functionEventDedup`
- `metaRateLimits`
- `kiddushMeta`
- `communityMeta`
- `dailyCalendarMeta`

### Storage Paths

- Social media uploads only:
- `social_posts/{postId}/{fileName}`

### Cloud Functions Triggers (already in prod backend)

- `onAdminPostCreate`
- `onPostLikeUpdate`
- `onPostReplyCreate`
- `onReplyLikeUpdate`
- `onOutbid`
- `onDirectMessageCreate`
- `onRabbiMessageCreate`
- `onUserUpdate`
- `onSocialPostDelete`
- `onKiddushSponsorshipCreate`
- `onKiddushSponsorshipDelete`
- `sendTestNotification` (callable)
- `runInitialCalendarSync` (HTTP secured by `SYNC_BOOTSTRAP_KEY`)
- Schedules:
- `syncCommunityOccasions` every 2 hours
- `syncKiddushCalendar` every 30 minutes
- `syncDailyCalendar` every 48 hours

### Functions Environment Variables

Required in Functions runtime:

- `SENDGRID_API_KEY`
- `KIDDUSH_BOOKING_NOTIFY_TO`
- `KIDDUSH_BOOKING_NOTIFY_FROM`
- `SYNC_BOOTSTRAP_KEY`

See: `/Users/ethangoizman/Downloads/Apps/IOS/KNB/functions/.env.example`

## 7) Notification Contract

### User token storage format

Under `users/{email}`:

- `fcmTokens`: map keyed by token string
- each token value includes:
- `platform` (must be `"android"` in Flutter app)
- `updatedAt` (server timestamp)

Legacy `fcmToken` fields are being deprecated in current code path. Flutter should write to `fcmTokens`.

### Notification types used

- `ADMIN_POST`
- `POST_LIKE`
- `POST_REPLY`
- `REPLY_LIKE`
- `OUTBID`
- `CHAT_MESSAGE`

Deep-link payload keys used by current navigation logic:

- `postId`
- `replyId`
- `honorId`
- `chatThreadId`
- `chatThreadOwnerEmail`
- `chatKind`
- `type`

## 8) Data Model Notes (Important)

1. `users` document IDs are lowercase email addresses in practice; normalize email casing consistently.
2. `social_posts`:
- top-level post: `parentPostId = null`
- reply: `parentPostId = <postId>`
- media:
- new format: `mediaItems: [ { type, storagePath, downloadURL, width, height, fileSizeBytes } ]`
- legacy compatibility field exists in backend (`media`)
3. Post content max length: 140
4. Social media file size hard limit: < 3MB (rules enforce)
5. `honors.currentWinner` is treated like user identifier (currently email expectation in functions)
6. `seat_reservations`: no update, only create/delete
7. Chat messages max content length: 1000
8. Notification preferences in `users.notificationPrefs`:
- `adminPosts`, `postLikes`, `postReplies`, `replyLikes`, `outbid`, `chatMessages`

## 9) Android Permissions + Manifest Checklist

Required:

- Internet/network
- FCM notifications
- Camera
- Photo/media access (Android 13+ photo permissions as needed)
- Location/sensors for compass feature (if using heading plugin requirements)

Also configure:

- Firebase messaging service + background handler
- Notification channel(s)
- Google Sign-In intent/config

## 10) Flutter App Architecture Recommendation

Use clean feature modules with repository layer:

1. `auth`
2. `calendar`
3. `social`
4. `chat`
5. `auction`
6. `seating`
7. `notifications`
8. `profile/settings`

Core shared modules:

1. `firebase` (instances/config/wrappers)
2. `models` (Firestore DTOs + mappers)
3. `navigation` (deep-link + push routing)
4. `cache/offline` (prefs + image cache + Firestore persistence)

State management: Riverpod or Bloc (pick one and standardize).

## 11) Migration Sequence (Execution Plan)

1. Bootstrap Flutter app + Firebase Android integration
2. Implement auth + user document provisioning
3. Implement read-only calendar surfaces (`kiddushCalendar`, `communityOccasions`, `dailyCalendar`)
4. Implement sponsorship flow (`kiddush_sponsorships`)
5. Implement social feed + image upload + replies + likes
6. Implement notification inbox + FCM token sync + deep linking
7. Implement auction bids + outbid handling display
8. Implement chat (direct + rabbi)
9. Implement seating reservations
10. Implement Siddur + compass
11. Finalize admin flows and polish
12. QA hardening + production release setup

## 12) QA Acceptance Checklist

Must pass before Android release:

1. Login/logout works for email + Google
2. User doc created/updated correctly in `users/{email}`
3. FCM token stored under `fcmTokens` with `platform: "android"`
4. Push notifications received foreground/background/terminated
5. Notification taps deep-link to correct screen
6. Social post create/edit/delete, reply, like, media upload all work
7. Storage uploads obey size/content-type constraints
8. Chat send/receive works for direct and rabbi flows
9. Auction bidding updates in real time; outbid notification arrives
10. Sponsorship create/delete mirrors correctly in calendar
11. Seat reserve/cancel behaves with security rules
12. Offline mode does not crash; reconnect resyncs correctly

## 13) Critical Risks To Watch

1. Inconsistent email normalization can break document lookups and permissions.
2. Android Google Sign-In misconfiguration (missing SHA fingerprints) will block social login.
3. Incorrect FCM token shape (`fcmToken` vs `fcmTokens`) breaks push delivery.
4. Firestore rule mismatches can silently fail writes in social/chat paths.
5. Missing composite indexes will break feed/reply queries.

## 14) Files Your Developer Should Read First

1. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/ARCHITECTURE.md`
2. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/KNB/FirestoreManager.swift`
3. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/KNB/Models.swift`
4. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/functions/index.js`
5. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/firestore.rules`
6. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/firestore.indexes.json`
7. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/storage.rules`
8. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/KNB/PushRegistrationManager.swift`
9. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/KNB/AuthenticationManager.swift`
10. `/Users/ethangoizman/Downloads/Apps/IOS/KNB/KNB/NavigationManager.swift`

## 15) Handoff Summary

You do not need a new backend design. Port the client to Flutter Android while preserving the exact Firebase contracts above. The backend already contains notifications, syncing, and data integrity logic; the Android app must comply with existing Firestore/Storage schemas and security rules.

# KNB App — Architecture Documentation

> **Last Updated:** February 22, 2026
> **Platform:** Native iOS (SwiftUI) + Firebase Backend
> **Minimum iOS:** iOS 17+
> **Node.js Runtime:** 20

---

## Table of Contents

1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [System Architecture Diagram](#system-architecture-diagram)
5. [iOS App Architecture](#ios-app-architecture)
6. [Data Models](#data-models)
7. [Firestore Database Schema](#firestore-database-schema)
8. [Firebase Cloud Functions](#firebase-cloud-functions)
9. [Authentication Flow](#authentication-flow)
10. [Push Notifications](#push-notifications)
11. [Security Rules](#security-rules)
12. [Scheduled Sync System](#scheduled-sync-system)
13. [Feature Deep Dives](#feature-deep-dives)
14. [Deployment](#deployment)

---

## Overview

KNB (Kiddush, Notifications, Bidding) is a native iOS community app for Heritage Congregation. It provides:

- **Hebrew Calendar** with Shabbat times and kiddush sponsorship booking
- **Social Feed** for community posts with image support, likes, and threaded replies
- **Auction System** for honor bidding with real-time updates
- **Kiddush Booking** with email notifications and calendar integration
- **Seat Reservations** for shul seating
- **Siddur** (prayer book) with full text
- **Push Notifications** with per-category user preferences
- **Admin Panel** for managing content and users

> **Note:** Despite the workspace folder name "APP SPROUT FLUTTER", this is a **native iOS SwiftUI** application — not Flutter.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | SwiftUI (iOS 17+) |
| **Language** | Swift 5.9+ |
| **Backend** | Firebase (Firestore, Functions, Auth, Storage, FCM) |
| **Cloud Functions** | Node.js 20, JavaScript |
| **Database** | Cloud Firestore (NoSQL) |
| **File Storage** | Firebase Storage |
| **Authentication** | Firebase Auth + Google Sign-In |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Email** | SendGrid REST API |
| **Web Scraping** | Cheerio (HTML parser) |
| **IDE** | Xcode (`.xcodeproj`) |

### Key Dependencies

**iOS (Swift Package Manager):**
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseStorage`
- `FirebaseMessaging`
- `GoogleSignIn`

**Cloud Functions (npm):**
- `firebase-admin` ^12.0.0
- `firebase-functions` ^5.0.0
- `cheerio` ^1.2.0

---

## Project Structure

```
KNB LOCAL/
│
├── KNB/                              # iOS app source code
│   ├── KNBApp.swift                  # App entry point, Firebase init
│   ├── ContentView.swift             # Root view (splash → auth → main)
│   ├── MainTabView.swift             # Tab bar controller (4 tabs)
│   │
│   ├── Models.swift                  # All data models
│   ├── FirestoreManager.swift        # Central Firestore data layer
│   ├── AuthenticationManager.swift   # Firebase Auth + Google Sign-In
│   │
│   ├── CalendarView.swift            # Hebrew calendar & kiddush
│   ├── HebrewCalendarService.swift   # Hebrew date calculations
│   ├── SponsorshipFormView.swift     # Kiddush booking form
│   │
│   ├── SocialFeedView.swift          # Social feed (posts list)
│   ├── PostCard.swift                # Individual post component
│   ├── PostComposerView.swift        # Create/compose posts
│   ├── ReplyThreadView.swift         # Threaded replies
│   ├── SocialMediaSupport.swift      # Image upload/download
│   │
│   ├── AuctionListView.swift         # Honor auction list
│   ├── HonorDetailView.swift         # Honor detail + bidding
│   ├── BidHistoryView.swift          # Bid history display
│   │
│   ├── SeatingView.swift             # Seat reservations
│   ├── SiddurView.swift              # Prayer book
│   ├── ProfileTabView.swift          # User profile + settings
│   ├── MoreMenuView.swift            # More menu / settings
│   ├── SettingsView.swift            # App settings
│   ├── AdminManagementView.swift     # Admin panel
│   │
│   ├── NotificationManager.swift     # In-app notifications
│   ├── NotificationListView.swift    # Notification inbox UI
│   ├── PushRegistrationManager.swift # FCM token management
│   ├── NetworkMonitor.swift          # Connectivity monitoring
│   ├── NetworkStatusBanner.swift     # Offline indicator
│   ├── NavigationManager.swift       # Navigation state
│   ├── UserCacheManager.swift        # User data caching
│   ├── CalendarCacheManager.swift    # Calendar data caching
│   ├── AppSettings.swift             # App-wide preferences
│   ├── Extensions.swift              # Swift extensions
│   ├── EmptyStateView.swift          # Reusable empty state
│   │
│   ├── Assets.xcassets/              # Images, colors, app icon
│   └── GoogleService-Info.plist      # Firebase iOS config
│
├── functions/                         # Firebase Cloud Functions
│   ├── index.js                      # All cloud functions (1,888 lines)
│   ├── package.json                  # Node.js config & deps
│   ├── .env                          # Secrets (SendGrid key, emails)
│   └── .env.example                  # Environment template
│
├── The KNB App.xcodeproj/            # Xcode project config
├── KNBTests/                         # Unit tests
├── KNBUITests/                       # UI tests
│
├── firebase.json                     # Firebase project config
├── .firebaserc                       # Firebase project alias
├── firestore.rules                   # Firestore security rules
├── firestore.indexes.json            # Firestore composite indexes
├── storage.rules                     # Storage security rules
│
├── deploy-all.sh                     # Backend deployment script
├── run-simulator.sh                  # iOS simulator script
│
├── BUG_REPORT.md                     # Known issues & bugs
├── ARCHITECTURE.md                   # This file
└── [14 other .md documentation files]
```

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                       │
│                                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ Calendar  │ │  Social  │ │  Siddur  │ │   More   │  ← Tabs  │
│  │   Tab     │ │   Tab    │ │   Tab    │ │   Tab    │          │
│  └─────┬────┘ └────┬─────┘ └──────────┘ └────┬─────┘          │
│        │           │                          │                 │
│  ┌─────┴───────────┴──────────────────────────┴─────┐          │
│  │              FirestoreManager (singleton)          │          │
│  │    Real-time listeners, CRUD, caching             │          │
│  └─────────────────────┬─────────────────────────────┘          │
│                        │                                        │
│  ┌─────────────────────┤                                        │
│  │ AuthenticationMgr   │  PushRegistrationMgr  NetworkMonitor   │
│  └─────────────────────┤                                        │
└────────────────────────┼────────────────────────────────────────┘
                         │
                    Firebase SDK
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌─────▼─────┐
    │Firestore│    │  Storage  │   │   Auth    │
    │   DB    │    │  (Images) │   │ (Google)  │
    └────┬────┘    └───────────┘   └───────────┘
         │
    ┌────▼────────────────────────────┐
    │      Cloud Functions (Node.js)  │
    │                                 │
    │  Triggers:                      │
    │  • onCreate / onUpdate          │
    │  • onSchedule (every 30 min)    │
    │                                 │
    │  External:                      │
    │  • FCM Push Notifications       │
    │  • SendGrid Email API           │
    │  • Heritage website scraping    │
    └─────────────────────────────────┘
```

---

## iOS App Architecture

### Pattern: Observable Object + SwiftUI

The app uses SwiftUI's native state management with `@ObservableObject` / `@StateObject` / `@EnvironmentObject`.

### Entry Point Flow

```
KNBApp.swift
  └── ContentView.swift
        ├── SplashScreen (2s)
        ├── LoginView (if not authenticated)
        └── MainTabView (if authenticated)
              ├── Tab 1: CalendarView
              ├── Tab 2: SocialFeedView
              ├── Tab 3: SiddurView
              └── Tab 4: MoreMenuView
                          ├── ProfileTabView
                          ├── AuctionListView
                          ├── SeatingView
                          ├── SettingsView
                          └── AdminManagementView (admin only)
```

### Core Managers

#### `FirestoreManager` (`@MainActor`, `ObservableObject`)

The central data layer — a singleton managing all Firestore operations.

**Responsibilities:**
- Real-time listeners for honors, sponsorships, community occasions, social posts, seat reservations, and current user
- CRUD operations for all collections
- Local state management via `@Published` properties
- Bid placement with Firestore transactions
- Social post creation with media uploads

**Key Published Properties:**
```swift
@Published var honors: [Honor]
@Published var currentUser: User?
@Published var socialPosts: [SocialPost]
@Published var kiddushSponsorships: [KiddushSponsorship]
@Published var seatReservations: [SeatReservation]
@Published var communityOccasions: [CommunityOccasionItem]
```

**Listeners Architecture:**
```
FirestoreManager
  ├── honorsListener        → honors collection
  ├── sponsorshipsListener  → kiddush_sponsorships collection
  ├── occasionsListener     → communityOccasions collection
  ├── socialPostsListener   → social_posts collection
  ├── seatsListener         → seat_reservations collection
  └── userListener          → users/{email} document
```

#### `AuthenticationManager` (`@MainActor`, `ObservableObject`)

Handles Firebase Auth with Google Sign-In.

**Flow:**
1. Check for existing Firebase Auth session
2. If exists: load user data from Firestore
3. If not: present Google Sign-In UI
4. On success: create/update user document in Firestore
5. Store FCM token for push notifications

**Published State:**
```swift
@Published var isAuthenticated: Bool
@Published var user: User?
@Published var isLoading: Bool
```

#### `PushRegistrationManager` (singleton)

Manages FCM token lifecycle and push notification permissions.

**Token Storage Format:**
```
users/{email}/fcmTokens/{token}: {
    platform: "iOS",
    updatedAt: Timestamp
}
```

#### `NetworkMonitor` (`@MainActor`, `ObservableObject`)

Uses `NWPathMonitor` to track connectivity state and display an offline banner.

---

## Data Models

### `Honor`

Represents an auction item that users can bid on.

```swift
struct Honor {
    let id: UUID
    var name: String           // Display name
    var description: String    // Description text
    var currentBid: Double     // Current highest bid
    var buyNowPrice: Double    // Buy Now price
    var currentWinner: String? // Name of current high bidder
    var bids: [Bid]           // Full bid history
    var isSold: Bool          // Whether Buy Now was used
    var category: String      // Grouping category
}
```

### `Bid`

Individual bid record within an honor.

```swift
struct Bid {
    let id: UUID
    var amount: Double       // Bid amount in dollars
    var bidderName: String   // Display name of bidder
    var timestamp: Date      // When bid was placed
    var comment: String?     // Optional bid comment
}
```

### `User`

User profile stored in Firestore at `users/{email}`.

```swift
struct User {
    var name: String
    var email: String                              // Document ID
    var totalPledged: Double                        // Running total of bids
    var isAdmin: Bool                              // Admin flag
    var notificationPrefs: NotificationPreferences? // Per-category prefs
    var fcmTokens: [String: TokenDetails]?         // Device tokens map
}
```

### `SocialPost`

Posts and replies in the social feed. Replies are stored in the same collection as posts, differentiated by `parentPostId`.

```swift
struct SocialPost {
    let id: String
    var authorName: String
    var authorEmail: String
    var content: String           // Max 140 characters
    var timestamp: Date
    var likes: [String]           // Array of liker emails
    var likeCount: Int
    var replyCount: Int
    var parentPostId: String?     // nil = top-level post, set = reply
    var editedAt: Date?
    var mediaItems: [SocialPostMedia]  // Up to 4 images
}
```

### `KiddushSponsorship`

Kiddush booking record.

```swift
struct KiddushSponsorship {
    let id: UUID
    var date: Date            // Shabbat date
    var sponsorName: String
    var sponsorEmail: String
    var occasion: String      // What it's for
    var tierName: String      // e.g. "Gold Kiddush"
    var tierAmount: Int       // Price in dollars
    var isAnonymous: Bool
    var timestamp: Date       // When booked
    var isPaid: Bool
}
```

### `SeatReservation`

Immutable seat reservation (create/delete only, no updates).

```swift
struct SeatReservation {
    let id: String
    let row: String
    let number: Int
    let reservedBy: String      // User email
    let reservedByName: String
    let timestamp: Date
}
```

### `AppNotification`

In-app notification stored in user's subcollection.

```swift
struct AppNotification {
    let id: String
    let type: NotificationType  // ADMIN_POST, POST_LIKE, POST_REPLY, REPLY_LIKE, OUTBID
    let title: String
    let body: String
    let data: [String: String]?
    let isRead: Bool
    let createdAt: Date
}
```

### `CommunityOccasionItem`

Community events scraped from the Heritage website.

```swift
struct CommunityOccasionItem {
    let id: String
    var category: CommunityOccasionCategory  // births, engagements, yahrzeit, etc.
    var categoryLabel: String
    var rawText: String
    var effectiveDateIso: String?
    var sourceDateText: String?
    var group: CommunityOccasionGroup        // time_sensitive, celebration, notice
    var isInPriorityWindow: Bool
    var sortRank: Int
    var source: String
    var updatedAt: Date?
}
```

---

## Firestore Database Schema

```
Firestore Root
│
├── users/{email}                          # User profiles (doc ID = email)
│   ├── name: string
│   ├── email: string
│   ├── totalPledged: number
│   ├── isAdmin: boolean
│   ├── notificationPrefs: map
│   │   ├── adminPosts: boolean
│   │   ├── postLikes: boolean
│   │   ├── postReplies: boolean
│   │   ├── replyLikes: boolean
│   │   └── outbid: boolean
│   ├── fcmTokens: map
│   │   └── {token}: { platform: string, updatedAt: timestamp }
│   └── notifications/{notificationId}     # Subcollection
│       ├── type: string
│       ├── title: string
│       ├── body: string
│       ├── data: map
│       ├── isRead: boolean
│       └── createdAt: timestamp
│
├── honors/{honorId}                       # Auction items
│   ├── name: string
│   ├── description: string
│   ├── currentBid: number
│   ├── buyNowPrice: number
│   ├── currentWinner: string
│   ├── isSold: boolean
│   ├── category: string
│   └── bids: array
│       └── [{ id, amount, bidderName, timestamp, comment }]
│
├── social_posts/{postId}                  # Posts AND replies (flat)
│   ├── authorName: string
│   ├── authorEmail: string
│   ├── content: string (max 140 chars)
│   ├── timestamp: timestamp
│   ├── likes: array of strings (emails)
│   ├── likeCount: number
│   ├── replyCount: number
│   ├── parentPostId: string | null
│   ├── editedAt: timestamp | null
│   ├── mediaItems: array
│   │   └── [{ type, storagePath, downloadURL, width, height, fileSizeBytes }]
│   └── media: map (legacy single-image field)
│
├── kiddush_sponsorships/{sponsorshipId}   # Kiddush bookings
│   ├── date: timestamp
│   ├── sponsorName: string
│   ├── sponsorEmail: string
│   ├── occasion: string
│   ├── tierName: string
│   ├── tierAmount: number
│   ├── isAnonymous: boolean
│   ├── timestamp: timestamp
│   ├── isPaid: boolean
│   └── bookingEmailSentAt: timestamp (set by Cloud Function)
│
├── kiddushCalendar/{isoDate}              # Synced calendar (public read)
│   ├── status: string ("available" | "sponsored")
│   ├── sponsor: string
│   ├── occasion: string
│   ├── source: string ("app" | "website")
│   ├── parsha: string
│   └── updatedAt: timestamp
│
├── available_shabbat_dates/{dateId}       # Admin-managed dates
│   └── [date configuration]
│
├── seat_reservations/{seatId}             # Seat bookings (immutable)
│   ├── row: string
│   ├── number: number
│   ├── reservedBy: string
│   ├── reservedByName: string
│   └── timestamp: timestamp
│
├── communityOccasions/{docId}             # Synced community events (read-only)
│   ├── category: string
│   ├── categoryLabel: string
│   ├── rawText: string
│   ├── effectiveDateIso: string
│   ├── sourceDateText: string
│   ├── group: string
│   ├── isInPriorityWindow: boolean
│   ├── sortRank: number
│   ├── source: string
│   └── updatedAt: timestamp
│
├── kiddushMeta/{docId}                    # Sync metadata (backend only)
│   └── lastSyncHash: string
│
└── communityMeta/{docId}                  # Sync metadata (backend only)
    └── lastSyncHash: string
```

### Storage Structure

```
Firebase Storage
└── social_posts/{postId}/{fileName}       # Post images
    metadata:
      authorEmail: string                  # Owner for delete permissions
    constraints:
      max size: 3 MB
      content type: image/*
      no updates (immutable)
```

---

## Firebase Cloud Functions

All functions are in `functions/index.js`. The codebase mixes Firebase Functions Gen 1 (Firestore triggers, callable) and Gen 2 (scheduled functions).

### Function Inventory

| Function | Type | Trigger | Description |
|----------|------|---------|-------------|
| `onAdminPostCreate` | Gen 1 Firestore | `social_posts/{postId}` onCreate | Sends push to all users when admin creates a post |
| `onPostLikeUpdate` | Gen 1 Firestore | `social_posts/{id}` onUpdate | Notifies post author when someone likes their post |
| `onPostReplyCreate` | Gen 1 Firestore | `social_posts/{replyId}` onCreate | Notifies parent post author when reply is created |
| `onReplyLikeUpdate` | Gen 1 Firestore | `social_posts/{id}` onUpdate | Notifies reply author when someone likes their reply |
| `onOutbid` | Gen 1 Firestore | `honors/{honorId}` onUpdate | Notifies previous winner when they are outbid |
| `onUserUpdate` | Gen 1 Firestore | `users/{userId}` onUpdate | Propagates name changes across posts, replies, and bids |
| `sendTestNotification` | Gen 1 Callable | HTTPS onCall | Debug/test push notification endpoint |
| `syncCommunityOccasions` | Gen 2 Scheduled | Every 30 minutes | Scrapes Heritage website for community occasions |
| `syncKiddushCalendar` | Gen 2 Scheduled | Every 30 minutes | Scrapes Heritage website for kiddush calendar |
| `onKiddushSponsorshipCreate` | Gen 1 Firestore | `kiddush_sponsorships/{id}` onCreate | Sends email notification + updates calendar |
| `onKiddushSponsorshipDelete` | Gen 1 Firestore | `kiddush_sponsorships/{id}` onDelete | Cleans up calendar entry |

### Notification Flow

```
User action (like, reply, bid, admin post)
    │
    ▼
Firestore document write
    │
    ▼
Cloud Function trigger fires
    │
    ├── Check notification preferences (user.notificationPrefs)
    ├── Look up recipient's FCM tokens (user.fcmTokens)
    ├── Send push via admin.messaging().sendEachForMulticast()
    ├── Write AppNotification to users/{email}/notifications
    └── Clean up invalid tokens on terminal errors
```

### Email Flow (Kiddush Sponsorship)

```
User submits sponsorship form
    │
    ▼
Firestore document created in kiddush_sponsorships
    │
    ▼
onKiddushSponsorshipCreate fires
    │
    ├── Sends HTML email via SendGrid REST API
    │   To: KIDDUSH_BOOKING_NOTIFY_TO (3 recipients)
    │   From: KIDDUSH_BOOKING_NOTIFY_FROM
    │
    ├── Updates kiddushCalendar/{date} document
    │   status: "sponsored", source: "app"
    │
    └── Sets bookingEmailSentAt for idempotency
```

---

## Authentication Flow

```
App Launch
    │
    ▼
KNBApp.swift → Firebase.configure()
    │
    ▼
ContentView.swift → authManager.checkAuthState()
    │
    ├── Has Firebase session? ──YES──► Load user from Firestore
    │                                        │
    │                                        ▼
    │                                  MainTabView
    │
    └── No session ──► LoginView
                           │
                           ▼
                    Google Sign-In
                           │
                           ▼
                    Firebase Auth (credential exchange)
                           │
                           ▼
                    Create/update user in Firestore
                    Store FCM token
                           │
                           ▼
                    MainTabView
```

### Role System

| Role | How Determined | Capabilities |
|------|---------------|-------------|
| **Regular User** | Default | View all, create posts/bids/sponsorships/seat reservations |
| **Admin** | `users/{email}.isAdmin == true` | All regular + create/delete honors, manage sponsorships, delete any posts, view admin panel |
| **Super Admin** | Hardcoded email in rules (`admin@knb.com`) | All admin + promote/demote other admins |

---

## Push Notifications

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   iOS App    │     │  Cloud       │     │    FCM       │
│              │────►│  Firestore   │────►│  (Firebase   │
│ Writes data  │     │  (triggers)  │     │  Messaging)  │
│              │     │              │     │              │
│ ◄────────────│─────│──────────────│─────│  Delivers    │
│ Receives push│     │  Cloud Fn    │     │  to device   │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Notification Types

| Type | Trigger | Recipient |
|------|---------|-----------|
| `ADMIN_POST` | Admin creates a social post | All users |
| `POST_LIKE` | Someone likes a post | Post author |
| `POST_REPLY` | Someone replies to a post | Post author |
| `REPLY_LIKE` | Someone likes a reply | Reply author |
| `OUTBID` | New bid on an honor | Previous highest bidder |

### User Preferences

Users can toggle each notification type via `notificationPrefs` on their user document. Cloud Functions check these before sending.

### Token Management

- Tokens are stored in `users/{email}.fcmTokens` as a map: `{ token: { platform: "iOS", updatedAt: timestamp } }`
- Multi-device support: each device has its own token entry
- Invalid tokens are cleaned up by Cloud Functions on send failure

---

## Security Rules

### Firestore Rules Summary

| Collection | Read | Create | Update | Delete |
|-----------|------|--------|--------|--------|
| `users` | Auth'd | Owner only | Owner (no email/admin change) or Super Admin | — |
| `users/notifications` | Owner only | Owner only | Owner only | Owner only |
| `honors` | Auth'd | Admin only | Auth'd (bid rules) or Admin | Admin only |
| `social_posts` | Auth'd | Auth'd (owner email match, content validation) | Author (edit) or Auth'd (likes/counts) | Author or Admin |
| `kiddush_sponsorships` | Auth'd | Auth'd (owner email match) | Admin only | Owner or Admin |
| `seat_reservations` | Auth'd | Auth'd (owner email match) | **Forbidden** | Owner or Admin |
| `kiddushCalendar` | **Public** | Forbidden | Forbidden | Forbidden |
| `communityOccasions` | Auth'd | Forbidden | Forbidden | Forbidden |
| `kiddushMeta` | Forbidden | Forbidden | Forbidden | Forbidden |
| `communityMeta` | Forbidden | Forbidden | Forbidden | Forbidden |

### Key Validation Rules

- **Social Posts:** Content <= 140 chars, must have content or media, media validated (type, size, dimensions)
- **Honors (bids):** Bid must increase, exactly one new bid entry per update
- **Seat Reservations:** Immutable (no updates)
- **Users:** Cannot change own email or admin status

### Storage Rules

- Social post images: 3 MB max, image/* content type, author ownership enforced via metadata
- All other paths: denied by default

---

## Scheduled Sync System

Two Cloud Functions run every 30 minutes to sync data from the Heritage Congregation website:

### `syncKiddushCalendar`

```
Schedule: */30 * * * * (every 30 min)
    │
    ▼
Fetch HTML from Heritage website homepage
    │
    ▼
Parse with Cheerio: extract kiddush calendar table
    │
    ├── For each Shabbat date row:
    │   ├── Parse date, parsha, sponsor, occasion
    │   ├── Determine status: "sponsored" or "available"
    │   └── Write to kiddushCalendar/{isoDate}
    │
    ├── Hash comparison: skip write if content unchanged
    │   (stored in kiddushMeta/lastSync.contentHash)
    │
    └── Preserve app-sourced sponsorships:
        If kiddushCalendar doc has source=="app", don't overwrite
```

### `syncCommunityOccasions`

```
Schedule: */30 * * * * (every 30 min)
    │
    ▼
Fetch HTML from Heritage website homepage
    │
    ▼
Parse with Cheerio: extract community occasions sections
    │
    ├── Parse each section (Births, Engagements, etc.)
    │   ├── Extract individual items with dates
    │   ├── Classify into groups: time_sensitive, celebration, notice
    │   ├── Compute sort rank and priority window
    │   └── Generate deterministic IDs
    │
    ├── Hash comparison: skip if unchanged
    │
    └── Write to communityOccasions collection
        (full replace via batch write)
```

---

## Feature Deep Dives

### Hebrew Calendar (`CalendarView`)

The calendar tab displays a monthly grid with Hebrew dates alongside Gregorian dates. Data comes from three sources:

1. **Hebrew dates** — Computed by `HebrewCalendarService` using the Hebrew calendar
2. **Kiddush calendar** — Real-time listener on `kiddushCalendar` collection (synced from website + app sponsorships)
3. **Community occasions** — Real-time listener on `communityOccasions` collection

Sponsorship booking uses `SponsorshipFormView` with tiers, occasion selection, and anonymous option. On submit, a Firestore document is created which triggers the Cloud Function email + calendar update.

### Social Feed (`SocialFeedView`)

A feed of 140-character posts with up to 4 images per post. Supports:
- **Likes:** Toggle via array manipulation on `likes` field
- **Replies:** Stored as separate `social_posts` documents with `parentPostId` set
- **Edit:** Author can edit content (tracked via `editedAt`)
- **Delete:** Author or admin can delete; cascading delete attempts to remove replies
- **Image upload:** Up to 4 images, compressed to JPEG, uploaded to Firebase Storage

Posts display with relative timestamps, author name, like count, reply count, and media thumbnails.

### Auction System (`AuctionListView` → `HonorDetailView`)

Honors are auction items with:
- **Bidding:** Firestore transaction ensures atomic bid placement (currentBid must increase, exactly one new bid entry)
- **Buy Now:** Immediate purchase at `buyNowPrice`, sets `isSold = true`
- **Outbid notifications:** Cloud Function detects `currentWinner` change and notifies previous winner
- **Categories:** Honors are grouped by category for display

### Seat Reservations (`SeatingView`)

Visual seat map with rows and numbered seats. Reservations are immutable documents — create to reserve, delete to release. The view generates a grid of seats and checks against existing `seat_reservations` documents.

### Siddur (`SiddurView`)

A full prayer book embedded in the app. At 171KB, it's the largest Swift file, containing the prayer text content.

---

## Deployment

### Backend Deployment

The `deploy-all.sh` script deploys all Firebase resources:

```bash
# Deploy everything
firebase deploy --only functions,firestore:rules,firestore:indexes,storage

# Deploy just functions
cd functions && npm run deploy

# Deploy just rules
firebase deploy --only firestore:rules,storage
```

### iOS Deployment

Built and deployed via Xcode. The `run-simulator.sh` script provides a quick simulator launch.

### Environment Variables

Cloud Functions require these environment variables in `functions/.env`:

| Variable | Purpose |
|----------|---------|
| `SENDGRID_API_KEY` | SendGrid API key for email delivery |
| `KIDDUSH_BOOKING_NOTIFY_TO` | Comma-separated recipient emails for booking notifications |
| `KIDDUSH_BOOKING_NOTIFY_FROM` | Sender email address for booking notifications |

### Firebase Project

- **Project ID:** `the-knb-app` (configured in `.firebaserc`)
- **Functions Runtime:** Node.js 20
- **Firestore:** Default database
- **Storage:** Default bucket

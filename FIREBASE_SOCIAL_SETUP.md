# Firebase Setup Instructions for Social Feed Feature

## Overview
This document provides step-by-step instructions to set up Firebase Firestore for the Social Feed feature in the KNB app.

## 1. Firestore Collection Structure

### Collection: `social_posts`

Each document in this collection represents a social post or reply with the following structure:

```
social_posts/{postId}
  - id: string (UUID)
  - authorName: string
  - authorEmail: string
  - content: string (max 140 characters)
  - timestamp: timestamp
  - likes: array<string> (array of user emails who liked the post)
  - likeCount: number
  - replyCount: number
  - parentPostId: string | null (null for top-level posts, postId for replies)
```

**Important Notes:**
- `parentPostId` should be `null` (not an empty string) for top-level posts
- `likes` array contains user email addresses
- `likeCount` and `replyCount` are maintained for efficient sorting

## 2. Firestore Security Rules

Add these rules to your Firestore security rules in the Firebase Console:

1. Go to Firebase Console → Firestore Database → Rules
2. Add the following rule for the `social_posts` collection:

```javascript
match /social_posts/{postId} {
  // Anyone authenticated can read posts
  allow read: if request.auth != null;
  
  // Anyone authenticated can create posts (top-level) or replies (with parentPostId)
  allow create: if request.auth != null 
    && request.resource.data.authorEmail == request.auth.token.email
    && request.resource.data.content.size() <= 140
    && request.resource.data.likeCount == 0
    && request.resource.data.replyCount == 0
    && (request.resource.data.parentPostId == null || request.resource.data.parentPostId is string);
  
  // Users can update their own posts OR update likes/reply counts
  allow update: if request.auth != null 
    && (resource.data.authorEmail == request.auth.token.email 
        || request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likes', 'likeCount', 'replyCount']));
  
  // Users can delete their own posts, admins can delete any
  allow delete: if request.auth != null 
    && (resource.data.authorEmail == request.auth.token.email 
        || get(/databases/$(database)/documents/users/$(request.auth.token.email)).data.isAdmin == true);
}
```

**Note:** The admin check requires a `users` collection with documents keyed by email containing an `isAdmin` boolean field.

## 3. Firestore Indexes Required

You need to create **3 composite indexes** in Firebase Console:

### Index 1: Sort by Newest Posts
- **Collection ID:** `social_posts`
- **Fields to index:**
  - `timestamp` (Descending)
- **Query scope:** Collection
- **Purpose:** Sort all posts by newest first (app filters for top-level posts in memory)

### Index 2: Sort by Most Liked Posts
- **Collection ID:** `social_posts`
- **Fields to index:**
  - `likeCount` (Descending)
  - `timestamp` (Descending)
- **Query scope:** Collection
- **Purpose:** Sort all posts by most liked, then by newest (app filters for top-level posts in memory)

**Note:** The app queries all posts and filters for top-level posts (where `parentPostId` is null or missing) in memory. This avoids the complexity of querying null values in Firestore.

### Index 3: Get Replies for a Post
- **Collection ID:** `social_posts`
- **Fields to index:**
  - `parentPostId` (Ascending)
  - `timestamp` (Ascending)
- **Query scope:** Collection
- **Purpose:** Get all replies for a post in chronological order

## How to Create Indexes

1. Go to Firebase Console → Firestore Database → Indexes
2. Click "Create Index"
3. Select collection: `social_posts`
4. Add fields in the order specified above
5. Set sort order (Ascending/Descending) as specified
6. Click "Create"

**Alternative:** Firebase may automatically prompt you to create these indexes when you first run queries. You can click the link in the error message to create them.

## 4. Testing the Setup

After setting up:

1. **Test Reading:** Try fetching posts - should work for any authenticated user
2. **Test Creating:** Create a post - should work if you're logged in
3. **Test Liking:** Like a post - should update the likes array
4. **Test Replying:** Reply to a post - should create a new document with `parentPostId` set
5. **Test Deleting:** Delete your own post - should work
6. **Test Admin Delete:** As admin, delete any post - should work

## 5. Important Notes

- **Character Limit:** Posts are limited to 140 characters (Twitter's original limit)
- **Real-time Updates:** The app uses Firestore listeners for real-time updates
- **Optimistic UI:** Likes update immediately in the UI before Firestore confirms
- **Threading:** Replies are linked to parent posts via `parentPostId`
- **Deletion:** Deleting a post also deletes all its replies

## 6. Troubleshooting

**Error: "Missing or insufficient permissions"**
- Check that security rules are correctly set
- Verify user is authenticated
- Check that `authorEmail` matches authenticated user's email

**Error: "The query requires an index"**
- Create the missing index as described above
- Wait a few minutes for index to build
- Try the query again

**Posts not appearing in real-time**
- Check that listeners are started in `onAppear`
- Verify Firestore rules allow reading
- Check console for error messages

**Likes not updating**
- Verify security rules allow updating `likes` and `likeCount`
- Check that user email is in the request
- Verify Firestore connection

## 7. Collection Path Summary

- **Main Collection:** `social_posts`
- **User Collection (for admin check):** `users/{email}` (should contain `isAdmin: boolean`)

That's it! Your Firebase setup is complete for the Social Feed feature.


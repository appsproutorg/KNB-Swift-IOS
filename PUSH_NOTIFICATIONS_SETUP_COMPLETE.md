# Complete Push Notifications Setup Guide (2024-2025)
## Step-by-Step Instructions for KNB App

This guide provides the latest, up-to-date instructions for setting up push notifications that work when your app is closed.

---

## Part 1: Apple Developer Portal Setup (APNs Configuration)

### Step 1.1: Generate APNs Authentication Key

1. **Go to Apple Developer Portal:**
   - Visit: https://developer.apple.com/account/
   - Sign in with your Apple Developer account

2. **Navigate to Keys:**
   - Click on **"Certificates, Identifiers & Profiles"** in the left sidebar
   - Click on **"Keys"** in the left sidebar
   - Click the **"+"** button (top left) to create a new key

3. **Configure the Key:**
   - **Key Name:** Enter a name like "KNB App Push Notifications"
   - **Enable:** Check **"Apple Push Notifications service (APNs)"**
   - Click **"Continue"**
   - Review and click **"Register"**

4. **Download and Save:**
   - **Download the `.p8` file** - This is your APNs Auth Key
   - **IMPORTANT:** Save this file securely - you can only download it once!
   - **Note the Key ID** (shown on the page, e.g., "ABC123XYZ")
   - **Note your Team ID** (found in the top right corner of Apple Developer portal, e.g., "P8WQ4HA33H")

---

## Part 2: Firebase Console Setup

### Step 2.1: Upload APNs Key to Firebase

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/
   - Select your project: **"the-knb-app"**

2. **Navigate to Cloud Messaging Settings:**
   - Click the **gear icon** (⚙️) next to "Project Overview"
   - Select **"Project settings"**
   - Click on the **"Cloud Messaging"** tab

3. **Upload APNs Authentication Key:**
   - Scroll down to **"Apple app configuration"**
   - Under **"APNs authentication key"**, click **"Upload"**
   - Click **"Browse"** and select your downloaded `.p8` file
   - Enter the **Key ID** (from Step 1.1)
   - Enter your **Team ID** (from Step 1.1)
   - Click **"Upload"**

✅ **You should see a green checkmark confirming the upload was successful.**

---

## Part 3: Xcode Project Configuration

### Step 3.1: Enable Push Notifications Capability

1. **Open your project in Xcode:**
   - Open `The KNB App.xcodeproj`

2. **Add Push Notifications Capability:**
   - Select your project in the navigator (top item)
   - Select the **"The KNB App"** target
   - Go to the **"Signing & Capabilities"** tab
   - Click the **"+ Capability"** button (top left)
   - Search for and add **"Push Notifications"**

3. **Add Background Modes:**
   - Still in "Signing & Capabilities"
   - Click **"+ Capability"** again
   - Search for and add **"Background Modes"**
   - Under Background Modes, check **"Remote notifications"**

✅ **You should now see both "Push Notifications" and "Background Modes" in your capabilities list.**

---

## Part 4: Firebase Cloud Functions Setup (Required to Send Notifications)

### Step 4.1: Install Firebase CLI

1. **Install Node.js** (if not already installed):
   - Download from: https://nodejs.org/
   - Install the LTS version

2. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

3. **Login to Firebase:**
   ```bash
   firebase login
   ```
   - This will open your browser to authenticate

### Step 4.2: Initialize Firebase Functions

1. **Navigate to your project directory:**
   ```bash
   cd "/Users/shmuli/Desktop/APP SPROUT LOCAL/KNB Git"
   ```

2. **Initialize Functions:**
   ```bash
   firebase init functions
   ```
   
   **When prompted:**
   - **Select "Use an existing project"** → Choose "the-knb-app"
   - **Language:** Select **"JavaScript"** (TypeScript is optional)
   - **ESLint:** Yes (recommended)
   - **Install dependencies:** Yes

3. **This creates a `functions` folder in your project**

### Step 4.3: Create the Push Notification Function

1. **Open `functions/index.js`** and replace its contents with:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function that sends push notifications when a document is created
 * in the push_notifications collection
 */
exports.sendPushNotification = functions.firestore
  .document('push_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    // Skip if already sent
    if (data.sent === true) {
      console.log('Notification already sent, skipping');
      return null;
    }
    
    const { fcmToken, title, body, notificationId, postId, userEmail } = data;
    
    // Validate required fields
    if (!fcmToken || !title || !body) {
      console.error('Missing required fields:', { fcmToken: !!fcmToken, title: !!title, body: !!body });
      await snap.ref.update({ 
        sent: false, 
        error: 'Missing required fields',
        failedAt: admin.firestore.FieldValue.serverTimestamp() 
      });
      return null;
    }
    
    // Construct the FCM message
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        notificationId: notificationId || '',
        postId: postId || '',
        userEmail: userEmail || '',
        type: 'social_notification',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            contentAvailable: true,
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'default',
        },
      },
    };
    
    try {
      // Send the notification
      const response = await admin.messaging().send(message);
      console.log('✅ Successfully sent message:', response);
      
      // Mark as sent
      await snap.ref.update({ 
        sent: true, 
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response 
      });
      
      return null;
    } catch (error) {
      console.error('❌ Error sending push notification:', error);
      
      // Mark as failed
      await snap.ref.update({ 
        sent: false, 
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp() 
      });
      
      // Don't throw - we don't want to retry automatically
      return null;
    }
  });
```

2. **Install dependencies:**
   ```bash
   cd functions
   npm install
   cd ..
   ```

### Step 4.4: Deploy the Cloud Function

1. **Deploy the function:**
   ```bash
   firebase deploy --only functions
   ```

2. **Wait for deployment to complete** (this may take a few minutes)

3. **Verify deployment:**
   - Go to Firebase Console → **Functions**
   - You should see `sendPushNotification` function listed

---

## Part 5: Update Firestore Security Rules

### Step 5.1: Add Rules for Push Notifications Collection

1. **Go to Firebase Console:**
   - Navigate to **Firestore Database** → **Rules** tab

2. **Add this rule to your existing rules** (add it before the closing brace):

```javascript
    // Push notifications queue - only authenticated users can create
    match /push_notifications/{notificationId} {
      allow create: if request.auth != null;
      // Cloud Functions have admin access, so they can read/write
      allow read, write: if false; // Functions use admin SDK
    }
```

3. **Click "Publish"** to save the rules

---

## Part 6: Test Push Notifications

### Step 6.1: Build and Run on Physical Device

⚠️ **IMPORTANT:** Push notifications **DO NOT work on the iOS Simulator**. You must test on a real iPhone or iPad.

1. **Connect your iPhone/iPad to your Mac**
2. **In Xcode:**
   - Select your device from the device dropdown (top toolbar)
   - Build and run the app (⌘R)

3. **Grant Notification Permissions:**
   - When the app launches, it will ask for notification permissions
   - Tap **"Allow"**

4. **Check FCM Token:**
   - Open the app and log in
   - Check Xcode console for: `🔔 FCM Registration token: ...`
   - Check Firestore: Go to `users/{your-email}` document
   - Verify `fcmToken` field exists

### Step 6.2: Test from Firebase Console

1. **Go to Firebase Console:**
   - Navigate to **Cloud Messaging** → **Send your first message**

2. **Send Test Message:**
   - **Notification title:** "Test Notification"
   - **Notification text:** "This is a test"
   - Click **"Send test message"**
   - **Enter your FCM token** (from Firestore or Xcode console)
   - Click **"Test"**

3. **Verify:**
   - Close the app completely (swipe up from app switcher)
   - You should receive the notification on your device

### Step 6.3: Test Real Notification Flow

1. **Have another user like or reply to your post** in the app
2. **Close your app completely**
3. **Wait a few seconds** - you should receive a push notification
4. **Tap the notification** - it should open the app

---

## Part 7: Troubleshooting

### Issue: "No FCM token found"

**Solution:**
- Make sure you're logged in
- Check Xcode console for FCM token registration
- Verify the token is stored in Firestore under `users/{email}/fcmToken`

### Issue: "Cloud Function not triggering"

**Solution:**
- Check Firebase Console → Functions → Logs
- Verify the function is deployed: `firebase functions:list`
- Check that documents are being created in `push_notifications` collection

### Issue: "Notifications not appearing when app is closed"

**Solutions:**
1. **Verify APNs is configured:**
   - Firebase Console → Project Settings → Cloud Messaging
   - Check that APNs Auth Key shows a green checkmark

2. **Check device settings:**
   - Settings → Notifications → The KNB App
   - Ensure notifications are enabled

3. **Verify Background Modes:**
   - Xcode → Signing & Capabilities
   - Ensure "Remote notifications" is checked

4. **Check Cloud Function logs:**
   - Firebase Console → Functions → Logs
   - Look for errors when notifications are created

### Issue: "Permission denied" errors

**Solution:**
- Make sure Firestore security rules allow creating documents in `push_notifications`
- Verify the user is authenticated when creating notifications

---

## Part 8: Verification Checklist

Before considering setup complete, verify:

- [ ] APNs Auth Key uploaded to Firebase Console
- [ ] Push Notifications capability added in Xcode
- [ ] Background Modes → Remote notifications enabled
- [ ] Cloud Function deployed successfully
- [ ] FCM token stored in Firestore for logged-in user
- [ ] Test notification received from Firebase Console
- [ ] Real notification received when app is closed

---

## Additional Notes

### FCM Token Updates
- FCM tokens automatically refresh periodically
- The app handles token updates automatically
- Tokens are stored in Firestore whenever they change

### Production Considerations
- For production, consider using **App Attest** instead of DeviceCheck for better security
- Monitor Cloud Function execution costs
- Set up error alerting for failed notifications

### Badge Count (Optional Enhancement)
To show unread count on app icon, modify the Cloud Function to:
1. Query Firestore for unread notifications
2. Set `badge` in the APNs payload to the unread count

---

## Support Resources

- **Firebase Documentation:** https://firebase.google.com/docs/cloud-messaging/ios/client
- **Apple APNs Documentation:** https://developer.apple.com/documentation/usernotifications
- **Firebase Functions Documentation:** https://firebase.google.com/docs/functions

---

**Last Updated:** January 2025


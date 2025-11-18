# 🚀 Automatic Deployment - One Command Setup

I've prepared everything! You just need to login once, then I can deploy everything automatically.

## Step 1: Login to Firebase (One Time Only)

Open Terminal and run:

```bash
cd "/Users/shmuli/Desktop/APP SPROUT LOCAL/KNB Git"
firebase login
```

**What happens:**
- Browser opens
- Sign in with your Google account
- Click "Allow"
- Terminal shows "Success! Logged in as..."

## Step 2: Run the Auto-Deploy Script

Once logged in, run this **one command**:

```bash
./deploy-all.sh
```

**This will automatically:**
- ✅ Deploy your Cloud Function
- ✅ Deploy Firestore Rules
- ✅ Set everything up

That's it! 🎉

---

## What I've Prepared For You

✅ **`firestore.rules`** - Complete Firestore security rules (including push_notifications)
✅ **`firebase.json`** - Updated to include Firestore rules deployment
✅ **`functions/index.js`** - Push notification function ready to deploy
✅ **`deploy-all.sh`** - One-command deployment script

---

## After Deployment

1. **Verify in Firebase Console:**
   - Go to: https://console.firebase.google.com/project/the-knb-app/functions
   - You should see `sendPushNotification` function ✅

2. **Test on your iPhone:**
   - Build and run the app
   - Log in
   - Check for FCM token in Firestore
   - Test with Firebase Console → Cloud Messaging

---

## Troubleshooting

**"Permission denied" when running script:**
```bash
chmod +x deploy-all.sh
```

**"Not logged in" error:**
- Run `firebase login` first
- Make sure you're using the correct Google account

**Deployment fails:**
- Check you have billing enabled (Cloud Functions require it)
- Verify project ID is correct: `the-knb-app`


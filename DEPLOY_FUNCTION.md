# Quick Deploy Guide - Cloud Function

I've set up all the files for you! Now you just need to:

## Step 1: Login to Firebase (30 seconds)

Open Terminal and run:
```bash
cd "/Users/shmuli/Desktop/APP SPROUT LOCAL/KNB Git"
firebase login
```

This will:
- Open your browser
- Ask you to sign in with your Google account (the one you use for Firebase)
- Authorize Firebase CLI
- Return to terminal showing "Success! Logged in as..."

## Step 2: Deploy the Function (2 minutes)

Once logged in, run:
```bash
firebase deploy --only functions
```

This will:
- Upload your function to Firebase
- Take about 2-3 minutes
- Show "✔ Deploy complete!" when done

## Step 3: Verify (30 seconds)

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project: **the-knb-app**
3. Click **Functions** in the left sidebar
4. You should see `sendPushNotification` function listed ✅

## That's it! 🎉

Your push notifications are now ready to work!

---

## What I Already Did For You ✅

- ✅ Created `.firebaserc` (project configuration)
- ✅ Created `firebase.json` (Firebase config)
- ✅ Created `functions/` folder
- ✅ Created `functions/package.json` (dependencies)
- ✅ Created `functions/index.js` (the actual function code)
- ✅ Installed all npm dependencies

## Next Steps After Deployment

1. **Update Firestore Rules** (I'll do this next)
2. **Test on your phone** (see Part 6 in the main guide)


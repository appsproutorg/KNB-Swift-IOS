const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Helper to send notifications
async function sendNotification(userId, notification) {
    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const prefs = userData.notificationPrefs || {};
        const tokensMap = userData.fcmTokens || {};

        // Check preferences
        if (notification.type === "ADMIN_POST" && prefs.adminPosts === false) return;
        if (notification.type === "POST_LIKE" && prefs.postLikes === false) return;
        if (notification.type === "POST_REPLY" && prefs.postReplies === false) return;
        if (notification.type === "REPLY_LIKE" && prefs.replyLikes === false) return;
        if (notification.type === "OUTBID" && prefs.outbid === false) return;

        // 1. Write to Firestore Inbox
        const notificationRef = db.collection("users").doc(userId).collection("notifications").doc();
        await notificationRef.set({
            id: notificationRef.id,
            ...notification,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 2. Send Push Notification
        const tokens = Object.keys(tokensMap);
        if (tokens.length === 0) {
            console.log(`📭 No FCM tokens found for user ${userId}`);
            return;
        }

        const message = {
            notification: {
                title: notification.title,
                body: notification.body,
            },
            data: notification.data || {},
            apns: {
                payload: {
                    aps: {
                        alert: {
                            title: notification.title,
                            body: notification.body,
                        },
                        sound: "default",
                        badge: 1,
                        // CRITICAL: Set interruption level to 'active' to force banner display
                        "interruption-level": "active",
                    },
                },
                headers: {
                    // High priority ensures immediate delivery
                    "apns-priority": "10",
                },
            },
            tokens: tokens,
        };

        console.log(`🚀 Sending push to ${tokens.length} tokens for user ${userId}`);
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`✅ Push response: ${response.successCount} successes, ${response.failureCount} failures`);

        // Cleanup invalid tokens
        if (response.failureCount > 0) {
            const updates = {};
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const failedToken = tokens[idx];
                    console.error(`❌ Failed to send to token ${failedToken}:`, resp.error);
                    updates[`fcmTokens.${failedToken}`] = admin.firestore.FieldValue.delete();
                }
            });
            if (Object.keys(updates).length > 0) {
                await db.collection("users").doc(userId).update(updates);
                console.log(`🧹 Cleaned up ${Object.keys(updates).length} invalid tokens`);
            }
        }
        return true;
    } catch (error) {
        console.error("❌ Error sending notification:", error);
        return false;
    }
}

// 1. Admin Post Notification
exports.onAdminPostCreate = functions.firestore
    .document("social_posts/{postId}")
    .onCreate(async (snap, context) => {
        const post = snap.data();

        // Check if author is admin (by email or flag)
        // Assuming admin email check or isAdmin flag on user. 
        // For simplicity, checking if post.isAdminPost is true (if model has it) or authorEmail specific.
        // The prompt said "anyone with admin badge".
        // We'll check the user doc of the author.

        const authorDoc = await db.collection("users").doc(post.authorEmail).get();
        const isAuthorAdmin = authorDoc.exists && authorDoc.data().isAdmin;

        if (!isAuthorAdmin) return;

        const notification = {
            type: "ADMIN_POST",
            title: "New Admin Post",
            body: `${post.authorName} posted: ${post.content.substring(0, 50)}...`,
            data: { postId: context.params.postId },
        };

        // Batch send to all users (naive implementation for <500 users)
        // For production scaling, use batched writes/sends or topics.
        const usersSnap = await db.collection("users").get();
        const promises = [];
        usersSnap.forEach((doc) => {
            if (doc.id !== post.authorEmail) { // Don't notify author
                promises.push(sendNotification(doc.id, notification));
            }
        });

        await Promise.all(promises);
    });

// 2. Post Like Notification
exports.onPostLikeUpdate = functions.firestore
    .document("social_posts/{postId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const postId = context.params.postId;

        const beforeLikes = before.likes || [];
        const afterLikes = after.likes || [];

        // Find new likers
        const newLikers = afterLikes.filter(email => !beforeLikes.includes(email));

        if (newLikers.length === 0) return;

        const authorEmail = after.authorEmail;

        for (const likerEmail of newLikers) {
            if (likerEmail === authorEmail) continue; // Don't notify self

            // Get liker name
            const likerDoc = await db.collection("users").doc(likerEmail).get();
            const likerName = likerDoc.exists ? likerDoc.data().name : "Someone";

            const notification = {
                type: "POST_LIKE",
                title: "New Like",
                body: `${likerName} liked your post`,
                data: { postId: postId },
            };

            await sendNotification(authorEmail, notification);
        }
    });

// 3. Post Reply Notification
// 3. Post Reply Notification
exports.onPostReplyCreate = functions.firestore
    .document("social_posts/{replyId}")
    .onCreate(async (snap, context) => {
        const reply = snap.data();
        const replyId = context.params.replyId;

        // Check if this is actually a reply (has parentPostId)
        if (!reply.parentPostId) return;

        const postId = reply.parentPostId;

        // Get parent post to find author
        const postDoc = await db.collection("social_posts").doc(postId).get();
        if (!postDoc.exists) return;

        const post = postDoc.data();
        const authorEmail = post.authorEmail;

        if (reply.authorEmail === authorEmail) return; // Don't notify self

        const notification = {
            type: "POST_REPLY",
            title: "New Reply",
            body: `${reply.authorName} replied to your post`,
            data: { postId: postId, replyId: replyId },
        };

        await sendNotification(authorEmail, notification);
    });

// 4. Reply Like Notification
// 4. Reply Like Notification
exports.onReplyLikeUpdate = functions.firestore
    .document("social_posts/{replyId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const replyId = context.params.replyId;

        // Check if this is a reply
        if (!after.parentPostId) return;

        const postId = after.parentPostId;

        const beforeLikes = before.likes || [];
        const afterLikes = after.likes || [];

        const newLikers = afterLikes.filter(email => !beforeLikes.includes(email));

        if (newLikers.length === 0) return;

        const authorEmail = after.authorEmail;

        for (const likerEmail of newLikers) {
            if (likerEmail === authorEmail) continue;

            const likerDoc = await db.collection("users").doc(likerEmail).get();
            const likerName = likerDoc.exists ? likerDoc.data().name : "Someone";

            const notification = {
                type: "REPLY_LIKE",
                title: "Reply Liked",
                body: `${likerName} liked your reply`,
                data: { postId: postId, replyId: replyId },
            };

            await sendNotification(authorEmail, notification);
        }
    });

// 5. Outbid Notification
exports.onOutbid = functions.firestore
    .document("honors/{honorId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const honorId = context.params.honorId;

        // Check if currentWinner changed and bid increased
        if (before.currentWinner === after.currentWinner) return;
        if (!before.currentWinner) return; // No previous winner to notify

        const previousWinnerEmail = before.currentWinner;
        const newWinnerEmail = after.currentWinner;

        if (previousWinnerEmail === newWinnerEmail) return;

        const notification = {
            type: "OUTBID",
            title: "You've been outbid!",
            body: `Someone outbid you on ${after.name}. Current bid: $${after.currentBid}`,
            data: { honorId: honorId },
        };

        await sendNotification(previousWinnerEmail, notification);
    });

// 6. Propagate Name Changes
exports.onUserUpdate = functions.firestore
    .document("users/{userEmail}")
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const userEmail = context.params.userEmail;

        // Only run if name changed
        if (newData.name === oldData.name) return null;

        console.log(`👤 User ${userEmail} changed name from "${oldData.name}" to "${newData.name}". Updating content...`);

        const batch = db.batch();
        let operationCount = 0;

        try {
            // 1. Update Posts
            const postsSnapshot = await db.collection("social_posts")
                .where("authorEmail", "==", userEmail)
                .get();

            postsSnapshot.docs.forEach(doc => {
                batch.update(doc.ref, { authorName: newData.name });
                operationCount++;
            });

            // 2. Update Replies (using Collection Group Query)
            const repliesSnapshot = await db.collectionGroup("replies")
                .where("authorEmail", "==", userEmail)
                .get();

            repliesSnapshot.docs.forEach(doc => {
                batch.update(doc.ref, { authorName: newData.name });
                operationCount++;
            });

            // Commit if there are updates
            if (operationCount > 0) {
                await batch.commit();
                console.log(`✅ Updated ${postsSnapshot.size} posts and ${repliesSnapshot.size} replies.`);
            } else {
                console.log("ℹ️ No content to update.");
            }
        } catch (error) {
            console.error("❌ Error updating user content:", error);
            if (error.code === 9 || error.message.includes("index")) {
                console.error("🚨 MISSING INDEX: You need to create a composite index for 'replies' collection group on 'authorEmail'. Check the Firebase Console logs for the direct link to create it.");
            }
        }
    });

// 7. Test Notification (Callable)
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    }

    const userEmail = context.auth.token.email;
    console.log(`🧪 Sending test notification to ${userEmail}`);

    const notification = {
        type: "ADMIN_POST", // Matches the check in sendNotification
        title: "Test Notification",
        body: "This is a test to verify your push notifications are working! 🚀",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        relatedId: "test_id"
    };

    const success = await sendNotification(userEmail, notification);

    if (success) {
        return { success: true, message: "Notification sent!" };
    } else {
        throw new functions.https.HttpsError('internal', 'Failed to send notification.');
    }
});

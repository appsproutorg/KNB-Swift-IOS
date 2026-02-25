const functions = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("node:crypto");
const cheerio = require("cheerio");

admin.initializeApp();
const db = admin.firestore();
const storageBucket = admin.storage().bucket();

function sanitizeNotificationData(rawData) {
    const data = rawData || {};
    return Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, String(value)])
    );
}

function isTerminalFcmTokenError(errorCode) {
    return (
        errorCode === "messaging/invalid-registration-token" ||
        errorCode === "messaging/registration-token-not-registered"
    );
}

async function shouldSkipDuplicateEvent(handlerName, eventId) {
    if (!eventId) return false;

    const dedupeRef = db.collection("_functionEventDedup").doc(`${handlerName}_${eventId}`);
    return db.runTransaction(async (transaction) => {
        const doc = await transaction.get(dedupeRef);
        if (doc.exists) {
            return true;
        }

        transaction.set(dedupeRef, {
            handlerName,
            eventId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return false;
    });
}

// Helper to send notifications
async function sendNotification(userId, notification, userDataOverride = null) {
    try {
        let userData = userDataOverride;
        if (!userData) {
            const userDoc = await db.collection("users").doc(userId).get();
            if (!userDoc.exists) return;
            userData = userDoc.data();
        }

        const prefs = userData.notificationPrefs || {};
        const tokensMap = userData.fcmTokens || {};

        // Check preferences
        if (notification.type === "ADMIN_POST" && prefs.adminPosts === false) return;
        if (notification.type === "POST_LIKE" && prefs.postLikes === false) return;
        if (notification.type === "POST_REPLY" && prefs.postReplies === false) return;
        if (notification.type === "REPLY_LIKE" && prefs.replyLikes === false) return;
        if (notification.type === "OUTBID" && prefs.outbid === false) return;
        if (notification.type === "CHAT_MESSAGE" && prefs.chatMessages === false) return;

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

        const dataPayload = sanitizeNotificationData({
            ...(notification.data || {}),
            type: notification.type,
        });

        const message = {
            notification: {
                title: notification.title,
                body: notification.body,
            },
            data: dataPayload,
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
                    const errorCode = resp.error?.code || "";
                    if (isTerminalFcmTokenError(errorCode)) {
                        updates[`fcmTokens.${failedToken}`] = admin.firestore.FieldValue.delete();
                    }
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

function chunkArray(items, chunkSize) {
    const chunks = [];
    for (let i = 0; i < items.length; i += chunkSize) {
        chunks.push(items.slice(i, i + chunkSize));
    }
    return chunks;
}

function normalizeEmail(email) {
    return normalizeWhitespace(email).toLowerCase();
}

function buildMessagePreview(content) {
    const normalized = normalizeWhitespace(String(content || ""));
    if (!normalized) {
        return "You have a new message.";
    }

    const maxLength = 120;
    return normalized.length > maxLength ?
        `${normalized.slice(0, maxLength - 3)}...` :
        normalized;
}

function extractSocialMediaPaths(data) {
    const paths = new Set();
    const mediaItems = Array.isArray(data.mediaItems) ? data.mediaItems : [];
    mediaItems.forEach((item) => {
        if (item && typeof item.storagePath === "string" && item.storagePath.length > 0) {
            paths.add(item.storagePath);
        }
    });

    if (data.media && typeof data.media === "object" && typeof data.media.storagePath === "string") {
        if (data.media.storagePath.length > 0) {
            paths.add(data.media.storagePath);
        }
    }

    return paths;
}

async function deleteStoragePaths(paths) {
    await Promise.all(
        Array.from(paths).map(async (path) => {
            try {
                await storageBucket.file(path).delete({ ignoreNotFound: true });
            } catch (error) {
                logger.warn("Failed deleting storage object during social cleanup.", {
                    path,
                    error: error.message,
                });
            }
        })
    );
}

// 1. Admin Post Notification
exports.onAdminPostCreate = functions.firestore
    .document("social_posts/{postId}")
    .onCreate(async (snap, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onAdminPostCreate", context.eventId)) {
                return;
            }

            const post = snap.data() || {};
            const authorEmail = normalizeWhitespace(post.authorEmail || "");
            if (!authorEmail) return;

            const authorDoc = await db.collection("users").doc(authorEmail).get();
            const isAuthorAdmin = authorDoc.exists && authorDoc.data().isAdmin;
            if (!isAuthorAdmin) return;

            const contentPreview = normalizeWhitespace(String(post.content || "")).slice(0, 50);
            const notification = {
                type: "ADMIN_POST",
                title: "New Admin Post",
                body: `${post.authorName || "Admin"} posted: ${contentPreview}${contentPreview.length === 50 ? "..." : ""}`,
                data: { postId: context.params.postId },
            };

            const usersSnap = await db.collection("users")
                .select("notificationPrefs", "fcmTokens")
                .get();
            await Promise.all(
                usersSnap.docs
                    .filter((doc) => doc.id !== authorEmail)
                    .map((doc) => sendNotification(doc.id, notification, doc.data()))
            );
        } catch (error) {
            logger.error("onAdminPostCreate failed.", {
                postId: context.params.postId,
                error: error.message,
            });
        }
    });

// 2. Post Like Notification
exports.onPostLikeUpdate = functions.firestore
    .document("social_posts/{postId}")
    .onUpdate(async (change, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onPostLikeUpdate", context.eventId)) {
                return;
            }

            const before = change.before.data() || {};
            const after = change.after.data() || {};
            const postId = context.params.postId;

            // Replies are handled by onReplyLikeUpdate.
            if (after.parentPostId) {
                return;
            }

            const beforeLikes = new Set(before.likes || []);
            const afterLikes = new Set(after.likes || []);
            const newLikers = Array.from(afterLikes).filter((email) => !beforeLikes.has(email));

            if (newLikers.length === 0) return;

            const authorEmail = normalizeWhitespace(after.authorEmail || "");
            if (!authorEmail) return;
            const authorDoc = await db.collection("users")
                .doc(authorEmail)
                .get();
            if (!authorDoc.exists) return;
            const authorData = authorDoc.data();

            await Promise.all(
                newLikers.map(async (likerEmail) => {
                    if (likerEmail === authorEmail) return;

                    const likerDoc = await db.collection("users").doc(likerEmail).get();
                    const likerName = likerDoc.exists ? likerDoc.data().name : "Someone";

                    const notification = {
                        type: "POST_LIKE",
                        title: "New Like",
                        body: `${likerName} liked your post`,
                        data: { postId },
                    };

                    await sendNotification(authorEmail, notification, authorData);
                })
            );
        } catch (error) {
            logger.error("onPostLikeUpdate failed.", {
                postId: context.params.postId,
                error: error.message,
            });
        }
    });

// 3. Post Reply Notification
// 3. Post Reply Notification
exports.onPostReplyCreate = functions.firestore
    .document("social_posts/{replyId}")
    .onCreate(async (snap, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onPostReplyCreate", context.eventId)) {
                return;
            }

            const reply = snap.data() || {};
            const replyId = context.params.replyId;
            const postId = normalizeWhitespace(reply.parentPostId || "");

            if (!postId) return;

            const parentRef = db.collection("social_posts").doc(postId);
            await parentRef.set(
                {
                    replyCount: admin.firestore.FieldValue.increment(1),
                },
                { merge: true }
            );

            const postDoc = await parentRef.get();
            if (!postDoc.exists) return;

            const post = postDoc.data() || {};
            const authorEmail = normalizeWhitespace(post.authorEmail || "");
            if (!authorEmail || reply.authorEmail === authorEmail) return;

            const content = String(reply.content || "");
            const preview = content.length > 100 ? `${content.slice(0, 100)}...` : content;

            const notification = {
                type: "POST_REPLY",
                title: "New Reply",
                body: `${reply.authorName || "Someone"} replied: "${preview}"`,
                data: { postId, replyId },
            };

            await sendNotification(authorEmail, notification);
        } catch (error) {
            logger.error("onPostReplyCreate failed.", {
                replyId: context.params.replyId,
                error: error.message,
            });
        }
    });

// 4. Reply Like Notification
// 4. Reply Like Notification
exports.onReplyLikeUpdate = functions.firestore
    .document("social_posts/{replyId}")
    .onUpdate(async (change, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onReplyLikeUpdate", context.eventId)) {
                return;
            }

            const before = change.before.data() || {};
            const after = change.after.data() || {};
            const replyId = context.params.replyId;

            if (!after.parentPostId) return;
            const postId = after.parentPostId;

            const beforeLikes = new Set(before.likes || []);
            const afterLikes = new Set(after.likes || []);
            const newLikers = Array.from(afterLikes).filter((email) => !beforeLikes.has(email));

            if (newLikers.length === 0) return;

            const authorEmail = normalizeWhitespace(after.authorEmail || "");
            if (!authorEmail) return;
            const authorDoc = await db.collection("users")
                .doc(authorEmail)
                .get();
            if (!authorDoc.exists) return;
            const authorData = authorDoc.data();

            await Promise.all(
                newLikers.map(async (likerEmail) => {
                    if (likerEmail === authorEmail) return;

                    const likerDoc = await db.collection("users").doc(likerEmail).get();
                    const likerName = likerDoc.exists ? likerDoc.data().name : "Someone";

                    const notification = {
                        type: "REPLY_LIKE",
                        title: "Reply Liked",
                        body: `${likerName} liked your reply`,
                        data: { postId, replyId },
                    };

                    await sendNotification(authorEmail, notification, authorData);
                })
            );
        } catch (error) {
            logger.error("onReplyLikeUpdate failed.", {
                replyId: context.params.replyId,
                error: error.message,
            });
        }
    });

// 5. Outbid Notification
exports.onOutbid = functions.firestore
    .document("honors/{honorId}")
    .onUpdate(async (change, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onOutbid", context.eventId)) {
                return;
            }

            const before = change.before.data() || {};
            const after = change.after.data() || {};
            const honorId = context.params.honorId;

            if (before.currentWinner === after.currentWinner) return;
            if (!before.currentWinner) return;

            const previousWinnerEmail = before.currentWinner;
            const newWinnerEmail = after.currentWinner;
            if (previousWinnerEmail === newWinnerEmail) return;

            const notification = {
                type: "OUTBID",
                title: "You've been outbid!",
                body: `Someone outbid you on ${after.name}. Current bid: $${after.currentBid}`,
                data: { honorId },
            };

            await sendNotification(previousWinnerEmail, notification);
        } catch (error) {
            logger.error("onOutbid failed.", {
                honorId: context.params.honorId,
                error: error.message,
            });
        }
    });

// 6. Direct Message Notification
exports.onDirectMessageCreate = functions.firestore
    .document("direct_messages/{messageId}")
    .onCreate(async (snap, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onDirectMessageCreate", context.eventId)) {
                return;
            }

            const message = snap.data() || {};
            const senderEmail = normalizeEmail(message.senderEmail || "");
            const senderName = normalizeWhitespace(message.senderName || "") || "Someone";
            const threadId = normalizeWhitespace(message.threadId || context.params.messageId);

            const participants = Array.isArray(message.participants) ?
                message.participants.map((email) => normalizeEmail(email)) :
                [];
            const fallbackRecipientEmail = participants.find((email) =>
                email && email !== senderEmail
            ) || "";
            const recipientEmail = normalizeEmail(message.recipientEmail || fallbackRecipientEmail);

            if (!senderEmail || !recipientEmail || senderEmail === recipientEmail) {
                return;
            }

            const notification = {
                type: "CHAT_MESSAGE",
                title: `New message from ${senderName}`,
                body: buildMessagePreview(message.content),
                data: {
                    chatKind: "direct",
                    chatThreadId: threadId,
                    senderEmail,
                },
            };

            await sendNotification(recipientEmail, notification);
        } catch (error) {
            logger.error("onDirectMessageCreate failed.", {
                messageId: context.params.messageId,
                error: error.message,
            });
        }
    });

// 7. Rabbi Message Notification
exports.onRabbiMessageCreate = functions.firestore
    .document("rabbi_messages/{messageId}")
    .onCreate(async (snap, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onRabbiMessageCreate", context.eventId)) {
                return;
            }

            const message = snap.data() || {};
            const senderEmail = normalizeEmail(message.senderEmail || "");
            const threadOwnerEmail = normalizeEmail(message.threadOwnerEmail || "");
            const senderName = normalizeWhitespace(message.senderName || "") || "Someone";

            if (!senderEmail || !threadOwnerEmail) {
                return;
            }

            let recipientEmails = [];
            if (senderEmail !== threadOwnerEmail) {
                recipientEmails = [threadOwnerEmail];
            } else {
                const rawRecipientEmails = Array.isArray(message.recipientEmails) ?
                    message.recipientEmails :
                    [];
                recipientEmails = rawRecipientEmails.map((email) => normalizeEmail(email));
            }

            recipientEmails = Array.from(new Set(
                recipientEmails.filter((email) => email && email !== senderEmail)
            ));

            if (recipientEmails.length === 0) {
                return;
            }

            const notification = {
                type: "CHAT_MESSAGE",
                title: `New message from ${senderName}`,
                body: buildMessagePreview(message.content),
                data: {
                    chatKind: "rabbi",
                    chatThreadOwnerEmail: threadOwnerEmail,
                    senderEmail,
                },
            };

            await Promise.all(
                recipientEmails.map((recipientEmail) =>
                    sendNotification(recipientEmail, notification)
                )
            );
        } catch (error) {
            logger.error("onRabbiMessageCreate failed.", {
                messageId: context.params.messageId,
                error: error.message,
            });
        }
    });

// 8. Propagate Name Changes
exports.onUserUpdate = functions.firestore
    .document("users/{userEmail}")
    .onUpdate(async (change, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onUserUpdate", context.eventId)) {
                return null;
            }

            const newData = change.after.data() || {};
            const oldData = change.before.data() || {};
            const userEmail = context.params.userEmail;

            if (newData.name === oldData.name) return null;

            console.log(`👤 User ${userEmail} changed name from "${oldData.name}" to "${newData.name}". Updating content...`);

            const postsSnapshot = await db.collection("social_posts")
                .where("authorEmail", "==", userEmail)
                .get();

            const docs = postsSnapshot.docs;
            if (!docs.length) {
                console.log("ℹ️ No content to update.");
                return null;
            }

            const chunks = chunkArray(docs, 450);
            for (const docsChunk of chunks) {
                const batch = db.batch();
                docsChunk.forEach((doc) => {
                    batch.update(doc.ref, { authorName: newData.name });
                });
                await batch.commit();
            }

            console.log(`✅ Updated ${docs.length} social post/reply documents.`);
        } catch (error) {
            console.error("❌ Error updating user content:", error);
        }
    });

exports.onSocialPostDelete = functions.firestore
    .document("social_posts/{postId}")
    .onDelete(async (snap, context) => {
        try {
            if (await shouldSkipDuplicateEvent("onSocialPostDelete", context.eventId)) {
                return;
            }

            const deletedPost = snap.data() || {};
            const postId = context.params.postId;
            const parentPostId = normalizeWhitespace(deletedPost.parentPostId || "");

            if (parentPostId) {
                const parentRef = db.collection("social_posts").doc(parentPostId);
                await db.runTransaction(async (transaction) => {
                    const parentDoc = await transaction.get(parentRef);
                    if (!parentDoc.exists) {
                        return;
                    }

                    const currentReplyCount = Number(parentDoc.data()?.replyCount || 0);
                    transaction.update(parentRef, {
                        replyCount: Math.max(0, currentReplyCount - 1),
                    });
                });
                return;
            }

            const replySnapshot = await db.collection("social_posts")
                .where("parentPostId", "==", postId)
                .get();

            const mediaPaths = new Set();
            mediaPaths.formUnion(extractSocialMediaPaths(deletedPost));
            replySnapshot.docs.forEach((replyDoc) => {
                extractSocialMediaPaths(replyDoc.data()).forEach((path) => mediaPaths.add(path));
            });

            const replyChunks = chunkArray(replySnapshot.docs, 450);
            for (const docsChunk of replyChunks) {
                const batch = db.batch();
                docsChunk.forEach((doc) => batch.delete(doc.ref));
                await batch.commit();
            }

            await deleteStoragePaths(mediaPaths);

            logger.info("Cascaded reply cleanup for deleted top-level post.", {
                postId,
                repliesDeleted: replySnapshot.size,
                mediaDeleted: mediaPaths.size,
            });
        } catch (error) {
            logger.error("onSocialPostDelete failed.", {
                postId: context.params.postId,
                error: error.message,
            });
        }
    });

// 7. Test Notification (Callable)
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    }

    const userEmail = context.auth.token.email;
    const rateLimitRef = db.collection("metaRateLimits").doc(`sendTestNotification_${userEmail}`);
    const rateLimitSnap = await rateLimitRef.get();
    const now = Date.now();
    const lastCalledAt = rateLimitSnap.exists ? rateLimitSnap.data().lastCalledAtMillis || 0 : 0;
    if (now - lastCalledAt < 60_000) {
        throw new functions.https.HttpsError(
            "resource-exhausted",
            "Please wait at least 60 seconds between test notifications."
        );
    }

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
        await rateLimitRef.set({ lastCalledAtMillis: now }, { merge: true });
        return { success: true, message: "Notification sent!" };
    } else {
        throw new functions.https.HttpsError('internal', 'Failed to send notification.');
    }
});

const KIDDUSH_CALENDAR_URL = "https://www.heritagecongregation.com/website/index.php";
const HERITAGE_HOME_URL = "https://www.heritagecongregation.com/website/index.php";
const DAILY_CALENDAR_SOURCE_URL = "https://www.heritagecongregation.com/contacts/website_calendar.php";
const KIDDUSH_COLLECTION = "kiddushCalendar";
const KIDDUSH_APP_SPONSORSHIPS_COLLECTION = "kiddush_sponsorships";
const KIDDUSH_META_DOC_PATH = "kiddushMeta/sync";
const KIDDUSH_SYNC_TIMEZONE = "America/Chicago";
const KIDDUSH_SYNC_USER_AGENT = "KNB-KiddushCalendarSync/1.0 (+Firebase Functions)";
const KIDDUSH_HTTP_TIMEOUT_MS = 15000;
const KIDDUSH_EMAIL_PROVIDER_URL = "https://api.sendgrid.com/v3/mail/send";
const KIDDUSH_REQUIRED_BOOKING_RECIPIENTS = [
    "kiddush@heritagecongregation.com",
];
const COMMUNITY_OCCASIONS_COLLECTION = "communityOccasions";
const COMMUNITY_META_DOC_PATH = "communityMeta/sync";
const COMMUNITY_SYNC_TIMEZONE = "America/Chicago";
const COMMUNITY_SYNC_USER_AGENT = "KNB-CommunityOccasionsSync/1.0 (+Firebase Functions)";
const COMMUNITY_HTTP_TIMEOUT_MS = 15000;
const DAILY_CALENDAR_COLLECTION = "dailyCalendar";
const DAILY_CALENDAR_META_COLLECTION = "dailyCalendarMeta";
const DAILY_CALENDAR_TIMEZONE = "America/Chicago";
const DAILY_CALENDAR_SYNC_USER_AGENT = "KNB-DailyCalendarSync/1.0 (+Firebase Functions)";
const DAILY_CALENDAR_HTTP_TIMEOUT_MS = 15000;
const DAILY_CALENDAR_FUTURE_MONTHS_AHEAD = 12;
const SYNC_BOOTSTRAP_KEY_ENV = "SYNC_BOOTSTRAP_KEY";

const MONTH_INDEX_MAP = {
    january: 0,
    february: 1,
    march: 2,
    april: 3,
    may: 4,
    june: 5,
    july: 6,
    august: 7,
    september: 8,
    october: 9,
    november: 10,
    december: 11,
};

const COMMUNITY_CATEGORY_LABELS = {
    births: "Births",
    bar_bas_mitzvahs: "Bar/Bas Mitzvahs",
    engagements: "Engagements",
    anniversaries: "Anniversaries",
    birthdays: "Birthdays",
    yahrzeit: "Yahrzeit",
    condolences: "Condolences",
};

const COMMUNITY_GROUP_RANK = {
    time_sensitive: 0,
    celebration: 1,
    notice: 2,
};

const COMMUNITY_CATEGORY_RANK = {
    anniversaries: 10,
    birthdays: 11,
    yahrzeit: 12,
    engagements: 20,
    births: 21,
    bar_bas_mitzvahs: 22,
    condolences: 30,
};

const DAILY_EVENT_CATEGORY_LABELS = {
    kiddush: "Kiddush",
    all: "All",
    men: "Men",
    women: "Women",
    boys: "Boys",
    girls: "Girls",
    kids: "Kids",
    holidays: "Holidays",
    parsha: "Parsha",
    rosh: "Rosh Chodesh",
    mevorchim: "Shabbos Mevorchim",
};

function normalizeWhitespace(value) {
    return (value || "").replace(/\s+/g, " ").trim();
}

function isValidEmailAddress(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function parseRecipientEmails(rawValue) {
    const recipients = (rawValue || "")
        .split(/[,\n;]+/)
        .map((email) => normalizeWhitespace(email).toLowerCase())
        .filter((email) => email.length > 0);

    return Array.from(new Set(recipients.filter(isValidEmailAddress)));
}

function escapeHtml(value) {
    return String(value || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function chicagoDateParts(date) {
    const formatter = new Intl.DateTimeFormat("en-US", {
        timeZone: KIDDUSH_SYNC_TIMEZONE,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    });

    const parts = formatter.formatToParts(date);
    const output = {};
    for (const part of parts) {
        if (part.type === "year" || part.type === "month" || part.type === "day") {
            output[part.type] = part.value;
        }
    }

    return output;
}

function toIsoDateFromDateInChicago(date) {
    const parts = chicagoDateParts(date);
    return `${parts.year}-${parts.month}-${parts.day}`;
}

function formatHumanDateInChicago(date) {
    return new Intl.DateTimeFormat("en-US", {
        timeZone: KIDDUSH_SYNC_TIMEZONE,
        month: "long",
        day: "numeric",
        year: "numeric",
    }).format(date);
}

function skipWhitespace(input, startIndex) {
    let index = startIndex;
    while (index < input.length) {
        const char = input[index];
        if (char !== " " && char !== "\n" && char !== "\r" && char !== "\t") {
            break;
        }
        index += 1;
    }
    return index;
}

function readSingleQuotedJsArg(input, startIndex) {
    if (input[startIndex] !== "'") {
        return null;
    }

    let index = startIndex + 1;
    let raw = "";

    while (index < input.length) {
        const char = input[index];
        if (char === "\\") {
            if (index + 1 >= input.length) {
                return null;
            }
            raw += char + input[index + 1];
            index += 2;
            continue;
        }
        if (char === "'") {
            return { raw, nextIndex: index + 1 };
        }
        raw += char;
        index += 1;
    }

    return null;
}

function decodeSingleQuotedJsValue(raw) {
    let decoded = "";
    for (let i = 0; i < raw.length; i += 1) {
        const char = raw[i];
        if (char !== "\\") {
            decoded += char;
            continue;
        }

        if (i + 1 >= raw.length) {
            decoded += "\\";
            continue;
        }

        const escaped = raw[i + 1];
        i += 1;

        if (escaped === "'") {
            decoded += "'";
        } else if (escaped === "\"") {
            decoded += "\"";
        } else if (escaped === "\\") {
            decoded += "\\";
        } else if (escaped === "n") {
            decoded += "\n";
        } else if (escaped === "r") {
            decoded += "\r";
        } else if (escaped === "t") {
            decoded += "\t";
        } else {
            decoded += escaped;
        }
    }

    return decoded;
}

function parseSponsorTextFromOnclick(onclickValue) {
    if (!onclickValue) {
        return null;
    }

    const openCall = "open_view_popup(";
    const callStart = onclickValue.indexOf(openCall);
    if (callStart === -1) {
        return null;
    }

    let index = callStart + openCall.length;
    const firstArg = readSingleQuotedJsArg(onclickValue, index);
    if (!firstArg) {
        return null;
    }

    index = skipWhitespace(onclickValue, firstArg.nextIndex);
    if (onclickValue[index] !== ",") {
        return null;
    }
    index = skipWhitespace(onclickValue, index + 1);

    const secondArg = readSingleQuotedJsArg(onclickValue, index);
    if (!secondArg) {
        return null;
    }

    const decodedSponsor = decodeSingleQuotedJsValue(secondArg.raw);
    const sponsorText = normalizeWhitespace(decodedSponsor);
    return sponsorText || null;
}

function parseDisplayEventFromOnclick(onclickValue) {
    if (!onclickValue) {
        return null;
    }

    const openCall = "display_event(";
    const callStart = onclickValue.indexOf(openCall);
    if (callStart === -1) {
        return null;
    }

    let index = callStart + openCall.length;
    const args = [];

    while (index < onclickValue.length) {
        index = skipWhitespace(onclickValue, index);

        if (onclickValue[index] === ")") {
            break;
        }

        const arg = readSingleQuotedJsArg(onclickValue, index);
        if (!arg) {
            return null;
        }

        args.push(decodeSingleQuotedJsValue(arg.raw));
        index = skipWhitespace(onclickValue, arg.nextIndex);

        if (onclickValue[index] === ",") {
            index += 1;
            continue;
        }

        if (onclickValue[index] === ")") {
            break;
        }

        return null;
    }

    if (args.length < 3) {
        return null;
    }

    return {
        header: normalizeWhitespace(decodeHtmlEntities(args[0])),
        category: normalizeWhitespace(decodeHtmlEntities(args[1])),
        messageHtml: String(args[2] || ""),
    };
}

function decodeHtmlEntities(rawValue) {
    if (rawValue === undefined || rawValue === null) {
        return "";
    }

    const content = String(rawValue);
    if (!content) {
        return "";
    }

    return cheerio.load(`<span>${content}</span>`).text();
}

function extractTextLinesFromHtml(rawHtml) {
    const html = String(rawHtml || "")
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<\/?div[^>]*>/gi, "\n")
        .replace(/<\/?p[^>]*>/gi, "\n")
        .replace(/\u00a0/g, " ");

    const decoded = decodeHtmlEntities(html);
    return decoded
        .split("\n")
        .map((line) => normalizeWhitespace(line))
        .filter((line) => line.length > 0);
}

function emptyDailyZmanim() {
    return {
        alos: null,
        netz: null,
        chatzos: null,
        shkia: null,
        tzes: null,
    };
}

function parseScheduleLine(rawLine) {
    const line = normalizeWhitespace(rawLine);
    if (!line) {
        return null;
    }

    const suffixMatch = line.match(/^(.*?)(\d{1,2}:\d{2}\s*(?:AM|PM))$/i);
    if (suffixMatch) {
        const title = normalizeWhitespace(suffixMatch[1].replace(/[:\-]+$/, ""));
        const timeText = normalizeWhitespace(suffixMatch[2].toUpperCase());
        return {
            title: title || line,
            timeText: timeText || null,
            rawLine: line,
        };
    }

    const prefixMatch = line.match(/^(\d{1,2}:\d{2}\s*(?:AM|PM))\s+(.+)$/i);
    if (prefixMatch) {
        const title = normalizeWhitespace(prefixMatch[2]);
        const timeText = normalizeWhitespace(prefixMatch[1].toUpperCase());
        return {
            title: title || line,
            timeText: timeText || null,
            rawLine: line,
        };
    }

    return {
        title: line,
        timeText: null,
        rawLine: line,
    };
}

function parseDailyScheduleAndZmanim(messageHtml) {
    const raw = String(messageHtml || "");
    const sections = raw.split(/<hr\s*\/?>/i);

    const scheduleLines = extractTextLinesFromHtml(sections[0] || "")
        .map(parseScheduleLine)
        .filter((line) => Boolean(line));

    const zmanim = emptyDailyZmanim();
    const zmanimSection = sections.slice(1).join("<br>");
    const zmanimLines = extractTextLinesFromHtml(zmanimSection);
    for (const line of zmanimLines) {
        const match = line.match(/^([A-Za-z]+)\s*:\s*(.+)$/);
        if (!match) {
            continue;
        }

        const key = normalizeWhitespace(match[1]).toLowerCase();
        const value = normalizeWhitespace(match[2]);
        if (!value) {
            continue;
        }

        if (key === "alos") {
            zmanim.alos = value;
        } else if (key === "netz") {
            zmanim.netz = value;
        } else if (key === "chatzos") {
            zmanim.chatzos = value;
        } else if (key === "shkia") {
            zmanim.shkia = value;
        } else if (key === "tzes") {
            zmanim.tzes = value;
        }
    }

    return {
        scheduleLines,
        zmanim,
    };
}

function toMonthKey(year, month) {
    return `${year}-${String(month).padStart(2, "0")}`;
}

function addMonthsToYearMonth(year, month, offset) {
    const date = new Date(Date.UTC(year, (month - 1) + offset, 1, 12, 0, 0));
    return {
        year: date.getUTCFullYear(),
        month: date.getUTCMonth() + 1,
    };
}

function buildSequentialMonthTargets(startYear, startMonth, count) {
    const targets = [];
    for (let i = 0; i < count; i += 1) {
        targets.push(addMonthsToYearMonth(startYear, startMonth, i));
    }
    return targets;
}

function weekdayLabelForDate(year, month, day) {
    const date = new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
    return new Intl.DateTimeFormat("en-US", {
        timeZone: DAILY_CALENDAR_TIMEZONE,
        weekday: "long",
    }).format(date);
}

function dailyCategoryKeyFromClassName(classNameValue) {
    const classes = normalizeWhitespace(classNameValue || "").split(" ").filter(Boolean);
    for (const className of classes) {
        if (!className.startsWith("calendar-")) {
            continue;
        }
        const key = className.replace(/^calendar-/, "").trim().toLowerCase();
        if (!key || key === "day") {
            continue;
        }
        if (key === "day" || key === "row") {
            continue;
        }
        return key;
    }
    return null;
}

function categoryLabelFromKey(categoryKey) {
    const normalizedKey = normalizeWhitespace(categoryKey || "").toLowerCase();
    if (DAILY_EVENT_CATEGORY_LABELS[normalizedKey]) {
        return DAILY_EVENT_CATEGORY_LABELS[normalizedKey];
    }
    if (!normalizedKey) {
        return "Event";
    }
    return normalizedKey
        .split("_")
        .map((segment) => segment ? `${segment[0].toUpperCase()}${segment.slice(1)}` : "")
        .join(" ");
}

function buildDailyCalendarEventId(isoDate, categoryKey, eventIndex, title) {
    const hash = crypto
        .createHash("sha1")
        .update(`${isoDate}|${categoryKey}|${eventIndex}|${title}`)
        .digest("hex")
        .slice(0, 16);

    return `${isoDate}_${categoryKey}_${hash}`;
}

function parseDailyCalendarMonth(html, year, month) {
    const $ = cheerio.load(html);
    const calendarTable = $("table.calendar").first();

    if (!calendarTable.length) {
        return {
            tableFound: false,
            rows: [],
        };
    }

    const rows = [];
    const monthKey = toMonthKey(year, month);

    calendarTable.find("td.calendar-day, td.calendar-day-today").each((_, cellElement) => {
        const cell = $(cellElement);
        const dayNumberText = normalizeWhitespace(cell.find("div.day-number").first().text());
        const day = Number(dayNumberText);
        if (Number.isNaN(day) || day < 1 || day > 31) {
            return;
        }

        const isoDate = toIsoDate(year, month - 1, day);
        const hebrewDate = normalizeWhitespace(cell.find("div.day-hebrew").first().text());
        const weekdayLabel = weekdayLabelForDate(year, month, day);

        const scheduleAnchor = cell.find("div.day-schedule a").first();
        let scheduleLines = [];
        let zmanim = emptyDailyZmanim();

        if (scheduleAnchor.length) {
            const scheduleOnclick = scheduleAnchor.attr("onclick") || "";
            const parsedSchedulePopup = parseDisplayEventFromOnclick(scheduleOnclick);
            if (parsedSchedulePopup && parsedSchedulePopup.category.toLowerCase() === "schedule") {
                const parsedSchedule = parseDailyScheduleAndZmanim(parsedSchedulePopup.messageHtml);
                scheduleLines = parsedSchedule.scheduleLines;
                zmanim = parsedSchedule.zmanim;
            }
        }

        const events = [];
        cell.children("div").each((eventIndex, divElement) => {
            const divNode = $(divElement);
            const rawClassName = divNode.attr("class") || "";

            if (
                rawClassName.includes("day-number") ||
                rawClassName.includes("day-hebrew") ||
                rawClassName.includes("day-schedule")
            ) {
                return;
            }

            const categoryKey = dailyCategoryKeyFromClassName(rawClassName);
            if (!categoryKey) {
                return;
            }

            const anchor = divNode.find("a").first();
            const anchorText = normalizeWhitespace(anchor.text().replace(/\u00a0/g, " "));
            const fallbackText = normalizeWhitespace(divNode.text().replace(/\u00a0/g, " "));
            const eventTitle = anchorText || fallbackText;
            if (!eventTitle) {
                return;
            }

            const popup = parseDisplayEventFromOnclick(anchor.attr("onclick") || "");
            const detailsText = popup ? extractTextLinesFromHtml(popup.messageHtml).join("\n") : null;

            events.push({
                id: buildDailyCalendarEventId(isoDate, categoryKey, eventIndex, eventTitle),
                categoryKey,
                categoryLabel: categoryLabelFromKey(categoryKey),
                title: eventTitle,
                headerText: popup ? popup.header : null,
                detailsText: detailsText && detailsText.length > 0 ? detailsText : null,
                sourceCssClass: `calendar-${categoryKey}`,
            });
        });

        rows.push({
            isoDate,
            monthKey,
            year,
            month,
            day,
            weekdayLabel,
            hebrewDate: hebrewDate || "",
            scheduleLines,
            zmanim,
            events,
            source: "website",
        });
    });

    return {
        tableFound: true,
        rows,
    };
}

function canonicalizeDailyCalendarDoc(row) {
    const normalizedRow = row || {};
    const scheduleLines = Array.isArray(normalizedRow.scheduleLines)
        ? normalizedRow.scheduleLines.map((line) => ({
            title: normalizeWhitespace(String(line?.title || "")),
            timeText: normalizeWhitespace(String(line?.timeText || "")) || null,
            rawLine: normalizeWhitespace(String(line?.rawLine || "")),
        }))
        : [];

    const events = Array.isArray(normalizedRow.events)
        ? normalizedRow.events.map((event) => ({
            id: normalizeWhitespace(String(event?.id || "")),
            categoryKey: normalizeWhitespace(String(event?.categoryKey || "")).toLowerCase(),
            categoryLabel: normalizeWhitespace(String(event?.categoryLabel || "")),
            title: normalizeWhitespace(String(event?.title || "")),
            headerText: normalizeWhitespace(String(event?.headerText || "")) || null,
            detailsText: normalizeWhitespace(String(event?.detailsText || "")) || null,
            sourceCssClass: normalizeWhitespace(String(event?.sourceCssClass || "")),
        }))
        : [];

    const zmanimValue = normalizedRow.zmanim || {};
    const zmanim = {
        alos: normalizeWhitespace(String(zmanimValue.alos || "")) || null,
        netz: normalizeWhitespace(String(zmanimValue.netz || "")) || null,
        chatzos: normalizeWhitespace(String(zmanimValue.chatzos || "")) || null,
        shkia: normalizeWhitespace(String(zmanimValue.shkia || "")) || null,
        tzes: normalizeWhitespace(String(zmanimValue.tzes || "")) || null,
    };

    return {
        isoDate: normalizeWhitespace(String(normalizedRow.isoDate || "")),
        monthKey: normalizeWhitespace(String(normalizedRow.monthKey || "")),
        year: Number(normalizedRow.year || 0),
        month: Number(normalizedRow.month || 0),
        day: Number(normalizedRow.day || 0),
        weekdayLabel: normalizeWhitespace(String(normalizedRow.weekdayLabel || "")),
        hebrewDate: normalizeWhitespace(String(normalizedRow.hebrewDate || "")),
        scheduleLines,
        zmanim,
        events,
        source: normalizeWhitespace(String(normalizedRow.source || "website")) || "website",
    };
}

function canonicalizeDailyCalendarDataset(rows) {
    return rows
        .map((row) => canonicalizeDailyCalendarDoc(row))
        .sort((a, b) => a.isoDate.localeCompare(b.isoDate));
}

function isSameDailyCalendarDocument(existingDoc, incomingDoc) {
    const existing = canonicalizeDailyCalendarDoc(existingDoc);
    const incoming = canonicalizeDailyCalendarDoc(incomingDoc);
    return JSON.stringify(existing) === JSON.stringify(incoming);
}

async function fetchDailyCalendarMonthHtml(year, month) {
    const sourceUrl = new URL(DAILY_CALENDAR_SOURCE_URL);
    sourceUrl.searchParams.set("month", String(month));
    sourceUrl.searchParams.set("year", String(year));

    const response = await fetch(sourceUrl.toString(), {
        method: "GET",
        headers: {
            "User-Agent": DAILY_CALENDAR_SYNC_USER_AGENT,
            Accept: "text/html,application/xhtml+xml",
        },
        signal: AbortSignal.timeout(DAILY_CALENDAR_HTTP_TIMEOUT_MS),
    });

    if (!response.ok) {
        throw new Error(`HTTP ${response.status} while fetching daily calendar source`);
    }

    return response.text();
}

async function runDailyCalendarMonthSync(year, month, triggerSource = "scheduled") {
    const monthKey = toMonthKey(year, month);
    const html = await fetchDailyCalendarMonthHtml(year, month);
    const parsed = parseDailyCalendarMonth(html, year, month);

    if (!parsed.tableFound) {
        throw new Error(`daily calendar table not found for ${monthKey}`);
    }
    if (!parsed.rows.length) {
        throw new Error(`daily calendar parser produced zero rows for ${monthKey}`);
    }

    const dataset = canonicalizeDailyCalendarDataset(parsed.rows);
    const datasetHash = computeDatasetHash(dataset);
    const metaRef = db.collection(DAILY_CALENDAR_META_COLLECTION).doc(monthKey);

    let previousHash = null;
    const metaSnap = await metaRef.get();
    if (metaSnap.exists) {
        previousHash = metaSnap.data()?.hash || null;
    }

    const existingSnapshot = await db.collection(DAILY_CALENDAR_COLLECTION)
        .where("monthKey", "==", monthKey)
        .get();

    const existingByIsoDate = new Map();
    existingSnapshot.forEach((doc) => {
        existingByIsoDate.set(doc.id, doc.data());
    });

    const incomingByIsoDate = new Map();
    for (const row of dataset) {
        incomingByIsoDate.set(row.isoDate, row);
    }

    const batch = db.batch();
    let upsertCount = 0;
    let deleteCount = 0;

    for (const row of dataset) {
        const existingDoc = existingByIsoDate.get(row.isoDate);
        if (!isSameDailyCalendarDocument(existingDoc, row)) {
            batch.set(
                db.collection(DAILY_CALENDAR_COLLECTION).doc(row.isoDate),
                {
                    ...row,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );
            upsertCount += 1;
        }
    }

    for (const [existingIsoDate] of existingByIsoDate) {
        if (!incomingByIsoDate.has(existingIsoDate)) {
            batch.delete(db.collection(DAILY_CALENDAR_COLLECTION).doc(existingIsoDate));
            deleteCount += 1;
        }
    }

    const hashChanged = previousHash !== datasetHash;
    const hasContentChanges = upsertCount > 0 || deleteCount > 0;
    const driftCorrection = !hashChanged && hasContentChanges;

    if (!hashChanged && !hasContentChanges) {
        logger.info("Daily calendar month unchanged; skipping writes.", {
            triggerSource,
            monthKey,
            rows: dataset.length,
            hash: datasetHash,
        });
        return {
            monthKey,
            rows: dataset.length,
            upserts: 0,
            deletes: 0,
            hash: datasetHash,
            skipped: true,
        };
    }

    batch.set(
        metaRef,
        {
            hash: datasetHash,
            docCount: dataset.length,
            source: "website",
            lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    await batch.commit();

    logger.info("Daily calendar month sync committed.", {
        triggerSource,
        monthKey,
        rows: dataset.length,
        upserts: upsertCount,
        deletes: deleteCount,
        hash: datasetHash,
        hashChanged,
        driftCorrection,
    });

    return {
        monthKey,
        rows: dataset.length,
        upserts: upsertCount,
        deletes: deleteCount,
        hash: datasetHash,
        skipped: false,
    };
}

async function runDailyCalendarSyncWindow(
    startYear,
    startMonth,
    monthCount,
    triggerSource = "scheduled",
    failFast = false
) {
    const targets = buildSequentialMonthTargets(startYear, startMonth, monthCount);
    const syncedMonthKeys = [];
    const failures = [];

    for (const target of targets) {
        const monthKey = toMonthKey(target.year, target.month);
        try {
            await runDailyCalendarMonthSync(target.year, target.month, triggerSource);
            syncedMonthKeys.push(monthKey);
        } catch (error) {
            failures.push({
                monthKey,
                error: error.message,
            });

            logger.error("Daily calendar month sync failed.", {
                triggerSource,
                monthKey,
                error: error.message,
            });

            if (failFast) {
                throw new Error(`Failed syncing ${monthKey}: ${error.message}`);
            }
        }
    }

    return {
        syncedMonthKeys,
        failures,
    };
}

function parseMonthDay(dateText) {
    const cleaned = normalizeWhitespace(dateText).replace(",", "");
    const match = cleaned.match(/^([A-Za-z]+)\s+(\d{1,2})$/);
    if (!match) {
        return null;
    }

    const monthName = match[1].toLowerCase();
    const monthIndex = MONTH_INDEX_MAP[monthName];
    const day = Number(match[2]);

    if (monthIndex === undefined || Number.isNaN(day) || day < 1 || day > 31) {
        return null;
    }

    return {
        monthIndex,
        day,
        displayDate: `${match[1]} ${day}`,
    };
}

function toIsoDate(year, monthIndex, day) {
    const monthIso = String(monthIndex + 1).padStart(2, "0");
    const dayIso = String(day).padStart(2, "0");
    return `${year}-${monthIso}-${dayIso}`;
}

function getChicagoTodayParts(now = new Date()) {
    const formatter = new Intl.DateTimeFormat("en-US", {
        timeZone: KIDDUSH_SYNC_TIMEZONE,
        year: "numeric",
        month: "numeric",
        day: "numeric",
    });

    const parts = formatter.formatToParts(now);
    const output = {};
    for (const part of parts) {
        if (part.type === "year" || part.type === "month" || part.type === "day") {
            output[part.type] = Number(part.value);
        }
    }

    return {
        year: output.year,
        month: output.month,
        day: output.day,
    };
}

function inferStartYear(firstMonthIndex, firstDay, todayParts) {
    const todayUtc = Date.UTC(todayParts.year, todayParts.month - 1, todayParts.day);
    const candidateYears = [todayParts.year - 1, todayParts.year, todayParts.year + 1];

    let chosenYear = candidateYears[0];
    let smallestDistance = Number.POSITIVE_INFINITY;

    for (const candidateYear of candidateYears) {
        const candidateUtc = Date.UTC(candidateYear, firstMonthIndex, firstDay);
        const distance = Math.abs(candidateUtc - todayUtc);
        if (distance < smallestDistance) {
            smallestDistance = distance;
            chosenYear = candidateYear;
        }
    }

    return chosenYear;
}

function normalizeKiddushRows(parsedRows, todayParts) {
    const rowsWithMonthDay = [];

    for (const row of parsedRows) {
        const parsedDate = parseMonthDay(row.dateText);
        if (!parsedDate) {
            throw new Error(`Unsupported Kiddush date format: "${row.dateText}"`);
        }

        rowsWithMonthDay.push({
            ...row,
            ...parsedDate,
        });
    }

    if (!rowsWithMonthDay.length) {
        return [];
    }

    let year = inferStartYear(
        rowsWithMonthDay[0].monthIndex,
        rowsWithMonthDay[0].day,
        todayParts
    );
    let previousMonthIndex = rowsWithMonthDay[0].monthIndex;
    let previousDay = rowsWithMonthDay[0].day;

    return rowsWithMonthDay.map((row, index) => {
        if (
            index > 0 &&
            (row.monthIndex < previousMonthIndex ||
                (row.monthIndex === previousMonthIndex && row.day < previousDay))
        ) {
            year += 1;
        }

        previousMonthIndex = row.monthIndex;
        previousDay = row.day;

        return {
            isoDate: toIsoDate(year, row.monthIndex, row.day),
            displayDate: row.displayDate,
            parsha: row.parshaText,
            status: row.status,
            sponsorText: row.status === "reserved" ? row.sponsorText || null : null,
            isAnonymous: false,
        };
    });
}

function canonicalizeDataset(rows) {
    return rows
        .map((row) => ({
            isoDate: row.isoDate,
            displayDate: row.displayDate,
            parsha: row.parsha,
            status: row.status,
            sponsorText: row.sponsorText ?? null,
            source: row.source ?? "website",
            sponsorName: row.sponsorName ?? null,
            sponsorEmail: row.sponsorEmail ?? null,
            isAnonymous: Boolean(row.isAnonymous),
        }))
        .sort((a, b) => a.isoDate.localeCompare(b.isoDate));
}

function computeDatasetHash(dataset) {
    return crypto
        .createHash("sha256")
        .update(JSON.stringify(dataset))
        .digest("hex");
}

function isSameCalendarDocument(existingDoc, incomingDoc) {
    if (!existingDoc) {
        return false;
    }

    const existingSponsor =
        existingDoc.sponsorText === undefined || existingDoc.sponsorText === null
            ? null
            : normalizeWhitespace(String(existingDoc.sponsorText));

    const incomingSponsor =
        incomingDoc.sponsorText === undefined || incomingDoc.sponsorText === null
            ? null
            : normalizeWhitespace(String(incomingDoc.sponsorText));

    return (
        normalizeWhitespace(String(existingDoc.isoDate || "")) === incomingDoc.isoDate &&
        normalizeWhitespace(String(existingDoc.displayDate || "")) === incomingDoc.displayDate &&
        normalizeWhitespace(String(existingDoc.parsha || "")) === incomingDoc.parsha &&
        normalizeWhitespace(String(existingDoc.status || "")) === incomingDoc.status &&
        existingSponsor === incomingSponsor &&
        normalizeWhitespace(String(existingDoc.source || "website")) ===
            normalizeWhitespace(String(incomingDoc.source || "website")) &&
        normalizeWhitespace(String(existingDoc.sponsorName || "")) ===
            normalizeWhitespace(String(incomingDoc.sponsorName || "")) &&
        normalizeWhitespace(String(existingDoc.sponsorEmail || "")) ===
            normalizeWhitespace(String(incomingDoc.sponsorEmail || "")) &&
        Boolean(existingDoc.isAnonymous) === Boolean(incomingDoc.isAnonymous)
    );
}

async function fetchAppSponsorshipsByIsoDate() {
    const snapshot = await db.collection(KIDDUSH_APP_SPONSORSHIPS_COLLECTION).get();
    const sponsorshipsByIsoDate = new Map();

    snapshot.forEach((doc) => {
        const data = doc.data() || {};
        const dateTimestamp = data.date;
        if (!dateTimestamp || typeof dateTimestamp.toDate !== "function") {
            return;
        }

        const sponsorshipDate = dateTimestamp.toDate();
        const isoDate = toIsoDateFromDateInChicago(sponsorshipDate);
        const sponsorNameRaw = normalizeWhitespace(data.sponsorName || "Anonymous Sponsor");
        const sponsorEmail = normalizeWhitespace(data.sponsorEmail || "");
        const occasion = normalizeWhitespace(data.occasion || "");
        const isAnonymous = Boolean(data.isAnonymous);
        const visibleSponsorName = isAnonymous ? "Anonymous Sponsor" : sponsorNameRaw;
        const sponsorText = occasion
            ? `Kiddush is sponsored by ${visibleSponsorName} on occasion of ${occasion}`
            : `Kiddush is sponsored by ${visibleSponsorName}`;

        const timestamp = data.timestamp && typeof data.timestamp.toDate === "function"
            ? data.timestamp.toDate().getTime()
            : 0;

        const existing = sponsorshipsByIsoDate.get(isoDate);
        if (!existing || timestamp >= existing.timestamp) {
            sponsorshipsByIsoDate.set(isoDate, {
                isoDate,
                sponsorName: sponsorNameRaw,
                sponsorEmail,
                sponsorText,
                isAnonymous,
                timestamp,
            });
        }
    });

    return sponsorshipsByIsoDate;
}

function mergeWebsiteWithAppReservations(websiteDataset, appSponsorshipsByIsoDate) {
    return websiteDataset.map((row) => {
        const appSponsorship = appSponsorshipsByIsoDate.get(row.isoDate);
        if (!appSponsorship) {
            return {
                ...row,
                source: "website",
                sponsorName: null,
                sponsorEmail: null,
                isAnonymous: false,
            };
        }

        // Preserve official website reserved entries; override only website "available".
        if (row.status === "reserved") {
            return {
                ...row,
                source: "website",
                sponsorName: null,
                sponsorEmail: null,
                isAnonymous: false,
            };
        }

        return {
            ...row,
            status: "reserved",
            sponsorText: appSponsorship.sponsorText,
            source: "app",
            sponsorName: appSponsorship.sponsorName,
            sponsorEmail: appSponsorship.sponsorEmail || null,
            isAnonymous: Boolean(appSponsorship.isAnonymous),
        };
    });
}

function isValidKiddushSponsorshipPayload(data) {
    return Boolean(
        data &&
        data.date &&
        typeof data.date.toDate === "function" &&
        typeof data.sponsorName === "string" &&
        data.sponsorName.trim().length > 0 &&
        typeof data.sponsorEmail === "string" &&
        data.sponsorEmail.trim().length > 0 &&
        typeof data.occasion === "string" &&
        typeof data.tierName === "string" &&
        Number.isFinite(Number(data.tierAmount)) &&
        typeof data.isAnonymous === "boolean"
    );
}

async function sendKiddushBookingEmail(sponsorshipId, data) {
    const apiKey = process.env.SENDGRID_API_KEY;
    const notifyToRaw = process.env.KIDDUSH_BOOKING_NOTIFY_TO;
    const notifyFrom = process.env.KIDDUSH_BOOKING_NOTIFY_FROM;
    const notifyToList = Array.from(new Set([
        ...parseRecipientEmails(notifyToRaw),
        ...KIDDUSH_REQUIRED_BOOKING_RECIPIENTS,
    ]));

    if (!apiKey || notifyToList.length === 0 || !notifyFrom) {
        logger.warn("Kiddush booking email skipped due to missing email env vars.", {
            hasApiKey: Boolean(apiKey),
            hasNotifyTo: notifyToList.length > 0,
            hasNotifyFrom: Boolean(notifyFrom),
        });
        return false;
    }

    const shabbatDate =
        data.date && typeof data.date.toDate === "function"
            ? toIsoDateFromDateInChicago(data.date.toDate())
            : "Unknown date";

    const sponsorName = normalizeWhitespace(data.sponsorName || "Unknown");
    const sponsorEmail = normalizeWhitespace(data.sponsorEmail || "Unknown");
    const occasion = normalizeWhitespace(data.occasion || "Not provided");
    const tierName = normalizeWhitespace(data.tierName || "Not provided");
    const tierAmount = data.tierAmount !== undefined ? String(data.tierAmount) : "Not provided";
    const anonymousLabel = data.isAnonymous ? "Yes" : "No";

    const subject = `New Kiddush Booking - ${shabbatDate}`;
    const textBody = [
        "A new Kiddush booking was made in the app.",
        "",
        `Sponsorship ID: ${sponsorshipId}`,
        `Shabbat Date: ${shabbatDate}`,
        `Sponsor Name: ${sponsorName}`,
        `Sponsor Email: ${sponsorEmail}`,
        `Anonymous: ${anonymousLabel}`,
        `Tier: ${tierName}`,
        `Tier Amount: ${tierAmount}`,
        `Occasion: ${occasion}`,
    ].join("\n");

    const rows = [
        ["Sponsorship ID", sponsorshipId],
        ["Shabbat Date", shabbatDate],
        ["Sponsor Name", sponsorName],
        ["Sponsor Email", sponsorEmail],
        ["Anonymous", anonymousLabel],
        ["Tier", tierName],
        ["Tier Amount", tierAmount],
        ["Occasion", occasion],
    ].map(([label, value]) => `
        <tr>
          <td style="padding:10px 12px;border-bottom:1px solid #e5e7eb;color:#4b5563;font-weight:600;width:180px;">${escapeHtml(label)}</td>
          <td style="padding:10px 12px;border-bottom:1px solid #e5e7eb;color:#111827;">${escapeHtml(value)}</td>
        </tr>
    `).join("");

    const htmlBody = `
      <div style="font-family:Arial,Helvetica,sans-serif;background:#f8fafc;padding:24px;">
        <div style="max-width:620px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;">
          <div style="background:#0f172a;color:#ffffff;padding:16px 20px;">
            <div style="font-size:18px;font-weight:700;">New Kiddush Booking</div>
            <div style="font-size:13px;opacity:0.9;margin-top:4px;">Submitted from the KNB app</div>
          </div>
          <div style="padding:18px 20px;">
            <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;font-size:14px;">
              ${rows}
            </table>
          </div>
        </div>
      </div>
    `;

    const response = await fetch(KIDDUSH_EMAIL_PROVIDER_URL, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            personalizations: [{
                to: notifyToList.map((email) => ({ email })),
            }],
            from: { email: notifyFrom },
            subject,
            content: [
                { type: "text/plain", value: textBody },
                { type: "text/html", value: htmlBody },
            ],
        }),
    });

    if (!response.ok) {
        const body = await response.text();
        logger.error("Failed to send Kiddush booking email.", {
            status: response.status,
            body,
        });
        return false;
    }

    return true;
}

function buildKiddushCalendarDocFromAppSponsorship(data) {
    const dateTimestamp = data.date;
    if (!dateTimestamp || typeof dateTimestamp.toDate !== "function") {
        return null;
    }

    const sponsorshipDate = dateTimestamp.toDate();
    const isoDate = toIsoDateFromDateInChicago(sponsorshipDate);
    const displayDate = formatHumanDateInChicago(sponsorshipDate).replace(/,\s+\d{4}$/, "");
    const sponsorNameRaw = normalizeWhitespace(data.sponsorName || "Anonymous Sponsor");
    const sponsorEmail = normalizeWhitespace(data.sponsorEmail || "");
    const occasion = normalizeWhitespace(data.occasion || "");
    const isAnonymous = Boolean(data.isAnonymous);
    const visibleSponsorName = isAnonymous ? "Anonymous Sponsor" : sponsorNameRaw;
    const sponsorText = occasion
        ? `Kiddush is sponsored by ${visibleSponsorName} on occasion of ${occasion}`
        : `Kiddush is sponsored by ${visibleSponsorName}`;

    return {
        docId: isoDate,
        payload: {
            isoDate,
            displayDate,
            parsha: normalizeWhitespace(data.parsha || ""),
            status: "reserved",
            sponsorText,
            source: "app",
            sponsorName: sponsorNameRaw,
            sponsorEmail: sponsorEmail || null,
            isAnonymous,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
    };
}

async function fetchKiddushCalendarHtml() {
    const response = await fetch(KIDDUSH_CALENDAR_URL, {
        method: "GET",
        headers: {
            "User-Agent": KIDDUSH_SYNC_USER_AGENT,
            Accept: "text/html,application/xhtml+xml",
        },
        signal: AbortSignal.timeout(KIDDUSH_HTTP_TIMEOUT_MS),
    });

    if (!response.ok) {
        throw new Error(`HTTP ${response.status} while fetching source calendar`);
    }

    return response.text();
}

function parseKiddushCalendarTable(html) {
    const $ = cheerio.load(html);
    const table = $("#ContactDetails").first();

    if (!table.length) {
        return {
            tableFound: false,
            rows: [],
        };
    }

    const rows = [];

    table.find("tr").each((_, rowElement) => {
        const cells = $(rowElement).find("td");
        if (cells.length < 3) {
            return;
        }

        const dateText = normalizeWhitespace($(cells[0]).text());
        const parshaText = normalizeWhitespace($(cells[1]).text());
        if (!dateText || !parshaText) {
            return;
        }

        const statusCell = $(cells[2]);
        const reservedAnchor = statusCell
            .find("a")
            .filter((__, anchorElement) => {
                const anchorText = normalizeWhitespace($(anchorElement).text()).toLowerCase();
                return anchorText.includes("reserved");
            })
            .first();

        if (reservedAnchor.length) {
            const onclickValue = reservedAnchor.attr("onclick") || "";
            const sponsorText = parseSponsorTextFromOnclick(onclickValue);
            if (!sponsorText) {
                throw new Error(
                    `Reserved row for "${dateText}" is missing a parseable sponsor text`
                );
            }
            rows.push({
                dateText,
                parshaText,
                status: "reserved",
                sponsorText,
            });
            return;
        }

        const statusText = normalizeWhitespace(statusCell.text()).toLowerCase();
        if (statusText.includes("available")) {
            rows.push({
                dateText,
                parshaText,
                status: "available",
                sponsorText: null,
            });
        }
    });

    return {
        tableFound: true,
        rows,
    };
}

async function fetchCommunityOccasionsHtml() {
    const response = await fetch(HERITAGE_HOME_URL, {
        method: "GET",
        headers: {
            "User-Agent": COMMUNITY_SYNC_USER_AGENT,
            Accept: "text/html,application/xhtml+xml",
        },
        signal: AbortSignal.timeout(COMMUNITY_HTTP_TIMEOUT_MS),
    });

    if (!response.ok) {
        throw new Error(`HTTP ${response.status} while fetching community occasions page`);
    }

    return response.text();
}

function normalizeCommunityCategoryHeader(headerText) {
    const normalized = normalizeWhitespace(headerText).toLowerCase().replace(/\.+$/, "");
    if (!normalized) {
        return null;
    }

    if (normalized.includes("bar/bas mitzvah")) {
        return {
            categoryKey: "bar_bas_mitzvahs",
            categoryLabel: COMMUNITY_CATEGORY_LABELS.bar_bas_mitzvahs,
        };
    }
    if (normalized.includes("births")) {
        return {
            categoryKey: "births",
            categoryLabel: COMMUNITY_CATEGORY_LABELS.births,
        };
    }
    if (normalized.includes("engagement")) {
        return {
            categoryKey: "engagements",
            categoryLabel: COMMUNITY_CATEGORY_LABELS.engagements,
        };
    }
    if (normalized.includes("anniversar")) {
        return {
            categoryKey: "anniversaries",
            categoryLabel: COMMUNITY_CATEGORY_LABELS.anniversaries,
        };
    }
    if (normalized.includes("birthday")) {
        return {
            categoryKey: "birthdays",
            categoryLabel: COMMUNITY_CATEGORY_LABELS.birthdays,
        };
    }
    if (normalized.includes("yahrzeit")) {
        return {
            categoryKey: "yahrzeit",
            categoryLabel: COMMUNITY_CATEGORY_LABELS.yahrzeit,
        };
    }
    if (normalized.includes("condolence")) {
        return {
            categoryKey: "condolences",
            categoryLabel: COMMUNITY_CATEGORY_LABELS.condolences,
        };
    }

    return null;
}

function parseCommunityOccasions(html) {
    const $ = cheerio.load(html);
    const celebrationsHeading = $("h3")
        .filter((_, element) => {
            const text = normalizeWhitespace($(element).text()).toLowerCase();
            return (
                text.includes("celebrations and rememberance") ||
                text.includes("celebrations and remembrance")
            );
        })
        .first();

    if (!celebrationsHeading.length) {
        return {
            sectionFound: false,
            rows: [],
            categoryCounts: {},
        };
    }

    let cardBody = celebrationsHeading.closest(".card-header").nextAll(".card-body").first();
    if (!cardBody.length) {
        cardBody = celebrationsHeading.closest(".column").find(".card-body").first();
    }

    if (!cardBody.length) {
        return {
            sectionFound: false,
            rows: [],
            categoryCounts: {},
        };
    }

    let currentCategory = null;
    const rows = [];
    const seen = new Set();
    const categoryCounts = {};

    cardBody.find("div.triangle-header, td").each((_, node) => {
        const tagName = (node.tagName || "").toLowerCase();
        const nodeElement = $(node);

        if (tagName === "div" && nodeElement.hasClass("triangle-header")) {
            currentCategory = normalizeCommunityCategoryHeader(nodeElement.text());
            return;
        }

        if (!currentCategory) {
            return;
        }

        if (nodeElement.find("div.triangle-header").length > 0) {
            return;
        }

        const rawText = normalizeWhitespace(nodeElement.text().replace(/\u00a0/g, " "));
        if (!rawText) {
            return;
        }

        if (rawText.toLowerCase() === currentCategory.categoryLabel.toLowerCase()) {
            return;
        }

        const dedupeKey = `${currentCategory.categoryKey}|${rawText.toLowerCase()}`;
        if (seen.has(dedupeKey)) {
            return;
        }
        seen.add(dedupeKey);

        rows.push({
            categoryKey: currentCategory.categoryKey,
            categoryLabel: currentCategory.categoryLabel,
            rawText,
        });
        categoryCounts[currentCategory.categoryKey] = (categoryCounts[currentCategory.categoryKey] || 0) + 1;
    });

    return {
        sectionFound: true,
        rows,
        categoryCounts,
    };
}

function communityGroupForCategory(categoryKey) {
    if (["anniversaries", "birthdays", "yahrzeit"].includes(categoryKey)) {
        return "time_sensitive";
    }
    if (categoryKey === "condolences") {
        return "notice";
    }
    return "celebration";
}

function parseFullDateFromText(rawText) {
    const fullDateMatch = rawText.match(
        /(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),\s*(\d{4})/i
    );
    if (!fullDateMatch) {
        return null;
    }

    const monthName = fullDateMatch[1];
    const monthIndex = MONTH_INDEX_MAP[monthName.toLowerCase()];
    const day = Number(fullDateMatch[2]);
    const year = Number(fullDateMatch[3]);
    if (monthIndex === undefined || Number.isNaN(day) || Number.isNaN(year) || day < 1 || day > 31) {
        return null;
    }

    return {
        sourceDateText: `${monthName} ${day}, ${year}`,
        monthIndex,
        day,
        year,
        isoDate: toIsoDate(year, monthIndex, day),
    };
}

function parseMonthDayFromText(rawText) {
    const monthDayMatch = rawText.match(
        /(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})(?!,\s*\d{4})/i
    );
    if (!monthDayMatch) {
        return null;
    }

    const monthName = monthDayMatch[1];
    const monthIndex = MONTH_INDEX_MAP[monthName.toLowerCase()];
    const day = Number(monthDayMatch[2]);
    if (monthIndex === undefined || Number.isNaN(day) || day < 1 || day > 31) {
        return null;
    }

    return {
        sourceDateText: `${monthName} ${day}`,
        monthIndex,
        day,
    };
}

function inferNearestRecurringIsoDate(monthIndex, day, todayParts) {
    const todayUtc = Date.UTC(todayParts.year, todayParts.month - 1, todayParts.day);
    const candidateYears = [todayParts.year - 1, todayParts.year, todayParts.year + 1];

    let chosenYear = candidateYears[0];
    let smallestDistance = Number.POSITIVE_INFINITY;

    for (const year of candidateYears) {
        const candidateUtc = Date.UTC(year, monthIndex, day);
        const distance = Math.abs(candidateUtc - todayUtc);
        if (distance < smallestDistance) {
            smallestDistance = distance;
            chosenYear = year;
        }
    }

    return toIsoDate(chosenYear, monthIndex, day);
}

function isoDateToDayNumber(isoDate) {
    const match = isoDate.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!match) {
        return null;
    }

    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day)) {
        return null;
    }

    return Math.floor(Date.UTC(year, month - 1, day) / 86400000);
}

function isInCommunityPriorityWindow(effectiveDateIso, todayIso) {
    if (!effectiveDateIso) {
        return false;
    }

    const dateDayNumber = isoDateToDayNumber(effectiveDateIso);
    const todayDayNumber = isoDateToDayNumber(todayIso);
    if (dateDayNumber === null || todayDayNumber === null) {
        return false;
    }

    const dayDifference = dateDayNumber - todayDayNumber;
    return dayDifference >= -14 && dayDifference <= 45;
}

function buildCommunityOccasionDocumentId(categoryKey, rawText) {
    const hash = crypto
        .createHash("sha256")
        .update(`${categoryKey}|${rawText.toLowerCase()}`)
        .digest("hex")
        .slice(0, 20);
    return `${categoryKey}_${hash}`;
}

function normalizeCommunityOccasionRows(parsedRows, todayParts) {
    const todayIso = toIsoDate(todayParts.year, todayParts.month - 1, todayParts.day);
    const normalizedRows = parsedRows.map((row) => {
        const fullDate = parseFullDateFromText(row.rawText);
        const monthDay = !fullDate ? parseMonthDayFromText(row.rawText) : null;
        let sourceDateText = fullDate?.sourceDateText || monthDay?.sourceDateText || null;
        let effectiveDateIso = fullDate?.isoDate || null;

        if (
            !effectiveDateIso &&
            monthDay &&
            ["anniversaries", "birthdays", "yahrzeit"].includes(row.categoryKey)
        ) {
            effectiveDateIso = inferNearestRecurringIsoDate(
                monthDay.monthIndex,
                monthDay.day,
                todayParts
            );
        }

        const group = communityGroupForCategory(row.categoryKey);
        const docId = buildCommunityOccasionDocumentId(row.categoryKey, row.rawText);

        return {
            id: docId,
            categoryKey: row.categoryKey,
            categoryLabel: row.categoryLabel || COMMUNITY_CATEGORY_LABELS[row.categoryKey] || row.categoryKey,
            rawText: row.rawText,
            effectiveDateIso,
            sourceDateText,
            group,
            isInPriorityWindow: isInCommunityPriorityWindow(effectiveDateIso, todayIso),
            source: "website",
            sortRank: 0,
        };
    });

    normalizedRows.sort((a, b) => {
        const groupDelta = (COMMUNITY_GROUP_RANK[a.group] || 99) - (COMMUNITY_GROUP_RANK[b.group] || 99);
        if (groupDelta !== 0) {
            return groupDelta;
        }

        if (a.group === "time_sensitive" || b.group === "time_sensitive") {
            const aDate = a.effectiveDateIso || "9999-12-31";
            const bDate = b.effectiveDateIso || "9999-12-31";
            if (aDate !== bDate) {
                return aDate.localeCompare(bDate);
            }
        }

        const categoryDelta =
            (COMMUNITY_CATEGORY_RANK[a.categoryKey] || 999) -
            (COMMUNITY_CATEGORY_RANK[b.categoryKey] || 999);
        if (categoryDelta !== 0) {
            return categoryDelta;
        }

        if ((a.effectiveDateIso || "") !== (b.effectiveDateIso || "")) {
            return (a.effectiveDateIso || "").localeCompare(b.effectiveDateIso || "");
        }

        return a.rawText.localeCompare(b.rawText);
    });

    return normalizedRows.map((row, index) => ({
        ...row,
        sortRank: index + 1,
    }));
}

function canonicalizeCommunityOccasionDataset(rows) {
    return rows
        .map((row) => ({
            id: row.id,
            categoryKey: row.categoryKey,
            categoryLabel: row.categoryLabel,
            rawText: row.rawText,
            effectiveDateIso: row.effectiveDateIso ?? null,
            sourceDateText: row.sourceDateText ?? null,
            group: row.group,
            isInPriorityWindow: Boolean(row.isInPriorityWindow),
            sortRank: Number(row.sortRank || 0),
            source: row.source || "website",
        }))
        .sort((a, b) => a.id.localeCompare(b.id));
}

function isSameCommunityOccasionDocument(existingDoc, incomingDoc) {
    if (!existingDoc) {
        return false;
    }

    return (
        normalizeWhitespace(String(existingDoc.id || "")) === incomingDoc.id &&
        normalizeWhitespace(String(existingDoc.categoryKey || "")) === incomingDoc.categoryKey &&
        normalizeWhitespace(String(existingDoc.categoryLabel || "")) === incomingDoc.categoryLabel &&
        normalizeWhitespace(String(existingDoc.rawText || "")) === incomingDoc.rawText &&
        normalizeWhitespace(String(existingDoc.effectiveDateIso || "")) ===
            normalizeWhitespace(String(incomingDoc.effectiveDateIso || "")) &&
        normalizeWhitespace(String(existingDoc.sourceDateText || "")) ===
            normalizeWhitespace(String(incomingDoc.sourceDateText || "")) &&
        normalizeWhitespace(String(existingDoc.group || "")) === incomingDoc.group &&
        Boolean(existingDoc.isInPriorityWindow) === Boolean(incomingDoc.isInPriorityWindow) &&
        Number(existingDoc.sortRank || 0) === Number(incomingDoc.sortRank || 0) &&
        normalizeWhitespace(String(existingDoc.source || "website")) ===
            normalizeWhitespace(String(incomingDoc.source || "website"))
    );
}

async function runCommunityOccasionsSync(triggerSource = "scheduled") {
    logger.info("Starting community occasions sync.", { triggerSource });

    let html;
    try {
        html = await fetchCommunityOccasionsHtml();
    } catch (error) {
        logger.error("Community occasions sync failed while fetching source HTML.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    let parsedResult;
    try {
        parsedResult = parseCommunityOccasions(html);
    } catch (error) {
        logger.error("Community occasions sync failed while parsing HTML.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    if (!parsedResult.sectionFound) {
        logger.error("Community occasions sync aborted: celebrations card was not found.", {
            triggerSource,
        });
        return;
    }

    if (!parsedResult.rows.length) {
        logger.error("Community occasions sync aborted: parsed zero entries.", {
            triggerSource,
        });
        return;
    }

    let dataset;
    try {
        const todayParts = getChicagoTodayParts();
        const normalizedRows = normalizeCommunityOccasionRows(parsedResult.rows, todayParts);
        if (!normalizedRows.length) {
            logger.error("Community occasions sync aborted: normalization produced zero entries.", {
                triggerSource,
            });
            return;
        }

        dataset = canonicalizeCommunityOccasionDataset(normalizedRows);
    } catch (error) {
        logger.error("Community occasions sync failed during normalization.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    const datasetHash = computeDatasetHash(dataset);
    const metaRef = db.doc(COMMUNITY_META_DOC_PATH);

    let previousHash = null;
    try {
        const metaSnap = await metaRef.get();
        previousHash = metaSnap.exists ? metaSnap.data().hash || null : null;
    } catch (error) {
        logger.error("Community occasions sync failed while reading metadata.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    let existingDocsSnapshot;
    try {
        existingDocsSnapshot = await db.collection(COMMUNITY_OCCASIONS_COLLECTION).get();
    } catch (error) {
        logger.error("Community occasions sync failed while reading existing docs.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    const existingById = new Map();
    existingDocsSnapshot.forEach((doc) => {
        existingById.set(doc.id, doc.data());
    });

    const incomingById = new Map();
    for (const row of dataset) {
        incomingById.set(row.id, row);
    }

    const batch = db.batch();
    let upsertCount = 0;
    let deleteCount = 0;

    for (const row of dataset) {
        const existingDoc = existingById.get(row.id);
        if (!isSameCommunityOccasionDocument(existingDoc, row)) {
            batch.set(
                db.collection(COMMUNITY_OCCASIONS_COLLECTION).doc(row.id),
                {
                    ...row,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }
            );
            upsertCount += 1;
        }
    }

    for (const [docId] of existingById) {
        if (!incomingById.has(docId)) {
            batch.delete(db.collection(COMMUNITY_OCCASIONS_COLLECTION).doc(docId));
            deleteCount += 1;
        }
    }

    const hashChanged = previousHash !== datasetHash;
    const hasContentChanges = upsertCount > 0 || deleteCount > 0;
    const driftCorrection = !hashChanged && hasContentChanges;

    if (!hashChanged && !hasContentChanges) {
        logger.info("Community occasions unchanged, skipping Firestore writes.", {
            triggerSource,
            rows: dataset.length,
            hash: datasetHash,
            categoryCounts: parsedResult.categoryCounts,
        });
        return;
    }

    batch.set(
        metaRef,
        {
            hash: datasetHash,
            lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    try {
        await batch.commit();
        logger.info("Community occasions sync committed.", {
            triggerSource,
            rows: dataset.length,
            upserts: upsertCount,
            deletes: deleteCount,
            hash: datasetHash,
            hashChanged,
            driftCorrection,
            categoryCounts: parsedResult.categoryCounts,
        });
    } catch (error) {
        logger.error("Community occasions sync failed while committing batch.", {
            triggerSource,
            error: error.message,
        });
    }
}

async function runKiddushCalendarSync(triggerSource = "scheduled") {
    logger.info("Starting Kiddush calendar sync.", { triggerSource });

    let html;
    try {
        html = await fetchKiddushCalendarHtml();
    } catch (error) {
        logger.error("Kiddush sync failed while fetching source HTML.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    let parsedResult;
    try {
        parsedResult = parseKiddushCalendarTable(html);
    } catch (error) {
        logger.error("Kiddush sync failed while parsing HTML.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    if (!parsedResult.tableFound) {
        logger.error("Kiddush sync aborted: table #ContactDetails was not found.", { triggerSource });
        return;
    }

    if (!parsedResult.rows.length) {
        logger.error("Kiddush sync aborted: parsed zero rows from #ContactDetails.", { triggerSource });
        return;
    }

    let dataset;
    try {
        const todayParts = getChicagoTodayParts();
        const normalizedRows = normalizeKiddushRows(parsedResult.rows, todayParts);
        if (!normalizedRows.length) {
            logger.error("Kiddush sync aborted: date normalization produced zero rows.", { triggerSource });
            return;
        }

        const appSponsorshipsByIsoDate = await fetchAppSponsorshipsByIsoDate();
        const mergedRows = mergeWebsiteWithAppReservations(
            normalizedRows,
            appSponsorshipsByIsoDate
        );
        dataset = canonicalizeDataset(mergedRows);

        const seenIsoDates = new Set();
        for (const row of dataset) {
            if (seenIsoDates.has(row.isoDate)) {
                throw new Error(`Duplicate isoDate found in parsed dataset: ${row.isoDate}`);
            }
            seenIsoDates.add(row.isoDate);
        }
    } catch (error) {
        logger.error("Kiddush sync failed during normalization.", {
            triggerSource,
            error: error.message,
        });
        return;
    }
    const datasetHash = computeDatasetHash(dataset);
    const metaRef = db.doc(KIDDUSH_META_DOC_PATH);

    let previousHash = null;
    try {
        const metaSnap = await metaRef.get();
        previousHash = metaSnap.exists ? metaSnap.data().hash || null : null;
    } catch (error) {
        logger.error("Kiddush sync failed while reading existing sync metadata.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    let existingDocsSnapshot;
    try {
        existingDocsSnapshot = await db.collection(KIDDUSH_COLLECTION).get();
    } catch (error) {
        logger.error("Kiddush sync failed while reading existing calendar docs.", {
            triggerSource,
            error: error.message,
        });
        return;
    }

    const existingById = new Map();
    existingDocsSnapshot.forEach((doc) => {
        existingById.set(doc.id, doc.data());
    });

    const incomingById = new Map();
    for (const row of dataset) {
        incomingById.set(row.isoDate, row);
    }

    const batch = db.batch();
    let upsertCount = 0;
    let deleteCount = 0;

    for (const row of dataset) {
        const existingDoc = existingById.get(row.isoDate);
        if (!isSameCalendarDocument(existingDoc, row)) {
            batch.set(
                db.collection(KIDDUSH_COLLECTION).doc(row.isoDate),
                {
                    ...row,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }
            );
            upsertCount += 1;
        }
    }

    for (const [docId] of existingById) {
        if (!incomingById.has(docId)) {
            batch.delete(db.collection(KIDDUSH_COLLECTION).doc(docId));
            deleteCount += 1;
        }
    }

    const hashChanged = previousHash !== datasetHash;
    const hasContentChanges = upsertCount > 0 || deleteCount > 0;
    const driftCorrection = !hashChanged && hasContentChanges;

    if (!hashChanged && !hasContentChanges) {
        logger.info("Kiddush calendar unchanged and already in sync, skipping Firestore writes.", {
            triggerSource,
            rows: dataset.length,
            hash: datasetHash,
        });
        return;
    }

    batch.set(
        metaRef,
        {
            hash: datasetHash,
            lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    try {
        await batch.commit();
        logger.info("Kiddush calendar sync committed.", {
            triggerSource,
            rows: dataset.length,
            upserts: upsertCount,
            deletes: deleteCount,
            hash: datasetHash,
            hashChanged,
            driftCorrection,
        });
    } catch (error) {
        logger.error("Kiddush sync failed while committing Firestore batch.", {
            triggerSource,
            error: error.message,
        });
    }
}

async function runDailyCalendarScheduledSync(triggerSource = "scheduled") {
    const today = getChicagoTodayParts();
    const monthCount = DAILY_CALENDAR_FUTURE_MONTHS_AHEAD + 1;

    logger.info("Starting daily calendar window sync.", {
        triggerSource,
        startYear: today.year,
        startMonth: today.month,
        futureMonthsAhead: DAILY_CALENDAR_FUTURE_MONTHS_AHEAD,
        monthCount,
    });

    const result = await runDailyCalendarSyncWindow(
        today.year,
        today.month,
        monthCount,
        triggerSource
    );

    logger.info("Daily calendar window sync finished.", {
        triggerSource,
        syncedMonthKeys: result.syncedMonthKeys,
        failures: result.failures,
    });
}

exports.runInitialCalendarSync = onRequest(
    {
        region: "us-central1",
        memory: "256MiB",
        timeoutSeconds: 540,
    },
    async (req, res) => {
        if (req.method !== "POST") {
            res.status(405).json({ ok: false, error: "Use POST" });
            return;
        }

        const expectedKey = process.env[SYNC_BOOTSTRAP_KEY_ENV];
        const providedKey = req.get("x-sync-bootstrap-key") || req.query.key;

        if (!expectedKey) {
            logger.error("Initial sync endpoint is missing required secret key env var.", {
                envVar: SYNC_BOOTSTRAP_KEY_ENV,
            });
            res.status(500).json({ ok: false, error: "Server missing bootstrap key configuration" });
            return;
        }

        if (!providedKey || providedKey !== expectedKey) {
            logger.warn("Rejected unauthorized initial sync request.");
            res.status(403).json({ ok: false, error: "Unauthorized" });
            return;
        }

        logger.info("Starting immediate post-deploy sync for calendar datasets.");

        await runKiddushCalendarSync("post_deploy_bootstrap");
        await runCommunityOccasionsSync("post_deploy_bootstrap");
        await runDailyCalendarScheduledSync("post_deploy_bootstrap");

        res.status(200).json({
            ok: true,
            message: "Triggered immediate calendar sync for Kiddush, community occasions, and daily calendar.",
        });
    }
);

exports.syncCommunityOccasions = onSchedule(
    {
        schedule: "every 2 hours",
        region: "us-central1",
        timeZone: COMMUNITY_SYNC_TIMEZONE,
        memory: "256MiB",
        timeoutSeconds: 60,
    },
    async () => runCommunityOccasionsSync("scheduled")
);

exports.syncKiddushCalendar = onSchedule(
    {
        schedule: "every 30 minutes",
        region: "us-central1",
        timeZone: KIDDUSH_SYNC_TIMEZONE,
        memory: "256MiB",
        timeoutSeconds: 60,
    },
    async () => runKiddushCalendarSync("scheduled")
);

exports.syncDailyCalendar = onSchedule(
    {
        schedule: "every 48 hours",
        region: "us-central1",
        timeZone: DAILY_CALENDAR_TIMEZONE,
        memory: "256MiB",
        timeoutSeconds: 540,
    },
    async () => runDailyCalendarScheduledSync("scheduled")
);

exports.onKiddushSponsorshipCreate = functions.firestore
    .document("kiddush_sponsorships/{sponsorshipId}")
    .onCreate(async (snap, context) => {
        const data = snap.data() || {};
        const sponsorshipId = context.params.sponsorshipId;

        if (await shouldSkipDuplicateEvent("onKiddushSponsorshipCreate", context.eventId)) {
            return;
        }

        if (data.bookingEmailSentAt) {
            return;
        }

        if (!isValidKiddushSponsorshipPayload(data)) {
            logger.error("Invalid sponsorship payload. Skipping email + mirror.", {
                sponsorshipId,
            });
            return;
        }

        try {
            const calendarDoc = buildKiddushCalendarDocFromAppSponsorship(data);
            if (calendarDoc) {
                await db.collection(KIDDUSH_COLLECTION).doc(calendarDoc.docId).set(
                    calendarDoc.payload,
                    { merge: true }
                );
                logger.info("Mirrored app sponsorship into kiddushCalendar.", {
                    sponsorshipId,
                    isoDate: calendarDoc.docId,
                });
            } else {
                logger.warn("Could not mirror sponsorship to kiddushCalendar: invalid date.", {
                    sponsorshipId,
                });
            }

            const emailSent = await sendKiddushBookingEmail(sponsorshipId, data);
            if (!emailSent) {
                return;
            }

            await snap.ref.set(
                {
                    bookingEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

            logger.info("Kiddush booking email sent.", { sponsorshipId });
        } catch (error) {
            logger.error("Error in onKiddushSponsorshipCreate email flow.", {
                sponsorshipId,
                error: error.message,
            });
        }
    });

exports.onKiddushSponsorshipDelete = functions.firestore
    .document("kiddush_sponsorships/{sponsorshipId}")
    .onDelete(async (snap, context) => {
        const data = snap.data() || {};
        const sponsorshipId = context.params.sponsorshipId;

        if (await shouldSkipDuplicateEvent("onKiddushSponsorshipDelete", context.eventId)) {
            return;
        }

        const calendarDoc = buildKiddushCalendarDocFromAppSponsorship(data);
        if (!calendarDoc) {
            logger.warn("Could not resolve isoDate for deleted sponsorship.", { sponsorshipId });
            return;
        }

        try {
            const calendarRef = db.collection(KIDDUSH_COLLECTION).doc(calendarDoc.docId);
            const txResult = await db.runTransaction(async (transaction) => {
                const calendarSnap = await transaction.get(calendarRef);

                if (!calendarSnap.exists) {
                    return { status: "missing" };
                }

                const existing = calendarSnap.data() || {};
                const source = normalizeWhitespace(String(existing.source || ""));
                if (source !== "app") {
                    return {
                        status: "skipped_source",
                        source: existing.source || null,
                    };
                }

                transaction.set(
                    calendarRef,
                    {
                        status: "available",
                        sponsorText: null,
                        source: "website",
                        sponsorName: null,
                        sponsorEmail: null,
                        isAnonymous: false,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    },
                    { merge: true }
                );

                return { status: "cleared" };
            });

            if (txResult.status === "missing") {
                logger.info("No mirrored calendar doc found on sponsorship delete.", {
                    sponsorshipId,
                    isoDate: calendarDoc.docId,
                });
                return;
            }

            if (txResult.status === "skipped_source") {
                logger.info("Skipped clearing calendar doc because source is not app.", {
                    sponsorshipId,
                    isoDate: calendarDoc.docId,
                    source: txResult.source,
                });
                return;
            }

            logger.info("Cleared app-mirrored calendar sponsorship after delete.", {
                sponsorshipId,
                isoDate: calendarDoc.docId,
            });

            // Immediately re-sync from source website so calendar always reflects latest live data.
            await runKiddushCalendarSync("sponsorship_delete");
        } catch (error) {
            logger.error("Error in onKiddushSponsorshipDelete.", {
                sponsorshipId,
                error: error.message,
            });
        }
    });

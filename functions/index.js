const functions = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("node:crypto");
const cheerio = require("cheerio");

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
            body: `${reply.authorName} replied: "${reply.content.length > 100 ? reply.content.substring(0, 100) + '...' : reply.content}"`,
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

const KIDDUSH_CALENDAR_URL = "https://www.heritagecongregation.com/website/index.php";
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
            normalizeWhitespace(String(incomingDoc.sponsorEmail || ""))
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
                sponsorName: visibleSponsorName,
                sponsorEmail,
                sponsorText,
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
            };
        }

        // Preserve official website reserved entries; override only website "available".
        if (row.status === "reserved") {
            return {
                ...row,
                source: "website",
                sponsorName: null,
                sponsorEmail: null,
            };
        }

        return {
            ...row,
            status: "reserved",
            sponsorText: appSponsorship.sponsorText,
            source: "app",
            sponsorName: appSponsorship.sponsorName,
            sponsorEmail: appSponsorship.sponsorEmail || null,
        };
    });
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
            sponsorName: visibleSponsorName,
            sponsorEmail: sponsorEmail || null,
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
                },
                { merge: true }
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

exports.onKiddushSponsorshipCreate = functions.firestore
    .document("kiddush_sponsorships/{sponsorshipId}")
    .onCreate(async (snap, context) => {
        const data = snap.data() || {};
        const sponsorshipId = context.params.sponsorshipId;

        if (data.bookingEmailSentAt) {
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

        const calendarDoc = buildKiddushCalendarDocFromAppSponsorship(data);
        if (!calendarDoc) {
            logger.warn("Could not resolve isoDate for deleted sponsorship.", { sponsorshipId });
            return;
        }

        try {
            const calendarRef = db.collection(KIDDUSH_COLLECTION).doc(calendarDoc.docId);
            const calendarSnap = await calendarRef.get();

            if (!calendarSnap.exists) {
                logger.info("No mirrored calendar doc found on sponsorship delete.", {
                    sponsorshipId,
                    isoDate: calendarDoc.docId,
                });
                return;
            }

            const existing = calendarSnap.data() || {};
            if (normalizeWhitespace(String(existing.source || "")) !== "app") {
                logger.info("Skipped clearing calendar doc because source is not app.", {
                    sponsorshipId,
                    isoDate: calendarDoc.docId,
                    source: existing.source || null,
                });
                return;
            }

            await calendarRef.set(
                {
                    status: "available",
                    sponsorText: null,
                    source: "website",
                    sponsorName: null,
                    sponsorEmail: null,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
            );

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

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


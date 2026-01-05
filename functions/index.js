/**
 * Supper App - Firebase Cloud Functions
 *
 * Push Notification System
 *
 * IMPORTANT: Notifications are sent ONLY to the recipient (User B),
 * never to the sender (User A).
 *
 * Triggers:
 * 1. onMessageCreated - When User A sends a message to User B
 * 2. onCallCreated - When User A calls User B
 * 3. onInquiryCreated - When a client sends an inquiry to a professional
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");

// Initialize Firebase Admin
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Get user's FCM token from Firestore
 * @param {string} userId - The user's ID
 * @returns {Promise<string|null>} - FCM token or null if not found
 */
async function getUserFcmToken(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData.fcmToken || null;
    }
    return null;
  } catch (error) {
    logger.error(`Error getting FCM token for user ${userId}:`, error);
    return null;
  }
}

/**
 * Get user's display name from Firestore
 * @param {string} userId - The user's ID
 * @returns {Promise<string>} - User's name or 'Someone'
 */
async function getUserName(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData.name || userData.displayName || "Someone";
    }
    return "Someone";
  } catch (error) {
    logger.error(`Error getting user name for ${userId}:`, error);
    return "Someone";
  }
}

/**
 * Get user's photo URL from Firestore
 * @param {string} userId - The user's ID
 * @returns {Promise<string|null>} - Photo URL or null
 */
async function getUserPhotoUrl(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData.photoUrl || userData.photoURL || null;
    }
    return null;
  } catch (error) {
    logger.error(`Error getting photo URL for ${userId}:`, error);
    return null;
  }
}

/**
 * Send FCM notification
 * @param {string} token - FCM token of recipient
 * @param {object} notification - Notification title and body
 * @param {object} data - Additional data payload
 * @returns {Promise<boolean>} - Success status
 */
async function sendNotification(token, notification, data) {
  if (!token) {
    logger.warn("No FCM token provided, skipping notification");
    return false;
  }

  try {
    const message = {
      token: token,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: data,
      android: {
        priority: "high",
        notification: {
          channelId: "chat_messages",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.send(message);
    logger.info("Notification sent successfully:", response);
    return true;
  } catch (error) {
    // Handle invalid token - remove it from user's document
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      logger.warn(`Invalid FCM token, should be removed: ${token}`);
    } else {
      logger.error("Error sending notification:", error);
    }
    return false;
  }
}

/**
 * MESSAGE NOTIFICATION
 *
 * Triggers when a new message is created in a conversation.
 * Sends notification ONLY to the recipient (User B), NOT to the sender (User A).
 *
 * Path: conversations/{conversationId}/messages/{messageId}
 */
exports.onMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data.data();
    const conversationId = event.params.conversationId;

    logger.info(`New message in conversation ${conversationId}`);

    // Get sender and receiver IDs
    const senderId = messageData.senderId;
    const receiverId = messageData.receiverId;

    // CRITICAL: Only send notification to receiver (User B), NOT sender (User A)
    if (!receiverId || receiverId === senderId) {
      logger.warn("No valid receiver or sender is receiver, skipping");
      return null;
    }

    // Get receiver's FCM token
    const receiverToken = await getUserFcmToken(receiverId);
    if (!receiverToken) {
      logger.warn(`No FCM token for receiver ${receiverId}`);
      return null;
    }

    // Get sender's name for notification
    const senderName = await getUserName(senderId);

    // Prepare notification content
    const messageText = messageData.text || "";
    const hasImage = messageData.imageUrl ? true : false;

    let notificationBody = messageText;
    if (hasImage && !messageText) {
      notificationBody = "Sent you a photo";
    } else if (hasImage && messageText) {
      notificationBody = `[Photo] ${messageText}`;
    }

    // Truncate long messages
    if (notificationBody.length > 100) {
      notificationBody = notificationBody.substring(0, 97) + "...";
    }

    // Send notification to receiver ONLY
    await sendNotification(
      receiverToken,
      {
        title: senderName,
        body: notificationBody,
      },
      {
        type: "message",
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      }
    );

    logger.info(`Message notification sent to ${receiverId} from ${senderId}`);
    return null;
  }
);

/**
 * CALL NOTIFICATION
 *
 * Triggers when a new call document is created.
 * Sends notification ONLY to the receiver (User B), NOT to the caller (User A).
 *
 * Path: calls/{callId}
 */
exports.onCallCreated = onDocumentCreated("calls/{callId}", async (event) => {
  const callData = event.data.data();
  const callId = event.params.callId;

  logger.info(`New call created: ${callId}`);
  logger.info(`Call data:`, JSON.stringify(callData));

  // Get caller and receiver IDs (support both field names)
  const callerId = callData.callerId;
  const receiverId = callData.receiverId || callData.calleeId;

  // CRITICAL: Only send notification to receiver (User B), NOT caller (User A)
  if (!receiverId || receiverId === callerId) {
    logger.warn("No valid receiver or caller is receiver, skipping");
    return null;
  }

  // Only send notification for incoming calls (status: 'calling' or 'ringing')
  const status = callData.status;
  if (status !== "calling" && status !== "ringing" && status !== "pending") {
    logger.info(`Call status is ${status}, not a new call, skipping`);
    return null;
  }

  // Get receiver's FCM token
  const receiverToken = await getUserFcmToken(receiverId);
  if (!receiverToken) {
    logger.warn(`No FCM token for receiver ${receiverId}`);
    return null;
  }

  // Get caller's name and photo - use from call data or fetch from user doc
  const callerName = callData.callerName || await getUserName(callerId);
  const callerPhotoUrl = callData.callerPhoto || await getUserPhotoUrl(callerId);

  // Send HIGH PRIORITY notification to receiver ONLY (for background/killed app)
  try {
    const message = {
      token: receiverToken,
      notification: {
        title: "Incoming Call",
        body: `${callerName} is calling you`,
      },
      data: {
        type: "call",
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerPhoto: callerPhotoUrl || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 60000, // 60 seconds - call expires
        notification: {
          channelId: "calls",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: "public",
          icon: "@mipmap/ic_launcher",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10", // High priority for iOS
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: "Incoming Call",
              body: `${callerName} is calling you`,
            },
            sound: "default",
            badge: 1,
            "content-available": 1,
            "mutable-content": 1,
            category: "INCOMING_CALL",
          },
        },
      },
    };

    const response = await messaging.send(message);
    logger.info(`Call notification sent successfully: ${response}`);
  } catch (error) {
    logger.error("Error sending call notification:", error);
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      logger.warn(`Invalid FCM token for receiver ${receiverId}`);
    }
  }

  logger.info(`Call notification sent to ${receiverId} from ${callerId}`);
  return null;
});

/**
 * INQUIRY NOTIFICATION (for Professional accounts)
 *
 * Triggers when a new inquiry is created for a professional.
 * Sends notification to the professional (service provider).
 *
 * Path: users/{professionalId}/inquiries/{inquiryId}
 */
exports.onInquiryCreated = onDocumentCreated(
  "users/{professionalId}/inquiries/{inquiryId}",
  async (event) => {
    const inquiryData = event.data.data();
    const professionalId = event.params.professionalId;
    const inquiryId = event.params.inquiryId;

    logger.info(`New inquiry ${inquiryId} for professional ${professionalId}`);

    // Get client who sent the inquiry
    const clientId = inquiryData.clientId || inquiryData.userId;
    if (!clientId) {
      logger.warn("No client ID in inquiry, skipping");
      return null;
    }

    // Don't notify if professional is sending inquiry to themselves
    if (clientId === professionalId) {
      logger.warn("Client is the professional, skipping");
      return null;
    }

    // Get professional's FCM token
    const professionalToken = await getUserFcmToken(professionalId);
    if (!professionalToken) {
      logger.warn(`No FCM token for professional ${professionalId}`);
      return null;
    }

    // Get client's name
    const clientName = await getUserName(clientId);

    // Prepare notification
    const serviceName = inquiryData.serviceName || "your service";
    const message = inquiryData.message || "";

    let notificationBody = `${clientName} sent an inquiry for ${serviceName}`;
    if (message) {
      const truncatedMessage =
        message.length > 50 ? message.substring(0, 47) + "..." : message;
      notificationBody = `${clientName}: "${truncatedMessage}"`;
    }

    // Send notification to professional ONLY
    await sendNotification(
      professionalToken,
      {
        title: "New Inquiry",
        body: notificationBody,
      },
      {
        type: "inquiry",
        inquiryId: inquiryId,
        clientId: clientId,
        clientName: clientName,
        serviceName: serviceName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      }
    );

    logger.info(
      `Inquiry notification sent to professional ${professionalId} from client ${clientId}`
    );
    return null;
  }
);

/**
 * CONNECTION REQUEST NOTIFICATION
 *
 * Triggers when someone sends a connection request.
 * Sends notification to the recipient of the request.
 *
 * Path: users/{userId}/connection_requests/{requestId}
 */
exports.onConnectionRequestCreated = onDocumentCreated(
  "users/{userId}/connection_requests/{requestId}",
  async (event) => {
    const requestData = event.data.data();
    const recipientId = event.params.userId;
    const requestId = event.params.requestId;

    logger.info(`New connection request ${requestId} for user ${recipientId}`);

    // Get sender ID
    const senderId = requestData.fromUserId || requestData.senderId;
    if (!senderId) {
      logger.warn("No sender ID in connection request, skipping");
      return null;
    }

    // Don't notify if sending to self
    if (senderId === recipientId) {
      logger.warn("Sender is recipient, skipping");
      return null;
    }

    // Get recipient's FCM token
    const recipientToken = await getUserFcmToken(recipientId);
    if (!recipientToken) {
      logger.warn(`No FCM token for recipient ${recipientId}`);
      return null;
    }

    // Get sender's name
    const senderName = await getUserName(senderId);

    // Send notification to recipient ONLY
    await sendNotification(
      recipientToken,
      {
        title: "Connection Request",
        body: `${senderName} wants to connect with you`,
      },
      {
        type: "connection_request",
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      }
    );

    logger.info(
      `Connection request notification sent to ${recipientId} from ${senderId}`
    );
    return null;
  }
);

// ============================================================
// BUSINESS STATS SCHEDULED FUNCTIONS
// ============================================================

/**
 * DAILY STATS RESET
 *
 * Runs every day at midnight (00:00) in UTC.
 * Resets todayOrders and todayEarnings for all businesses.
 *
 * Also archives the previous day's stats to business_daily_stats collection
 * for historical reporting.
 */
exports.resetDailyBusinessStats = onSchedule(
  {
    schedule: "0 0 * * *", // Every day at midnight UTC
    timeZone: "UTC",
    retryCount: 3,
  },
  async (event) => {
    logger.info("Starting daily business stats reset...");

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateKey = yesterday.toISOString().split("T")[0]; // YYYY-MM-DD

    try {
      // Get all active businesses
      const businessesSnapshot = await db
        .collection("businesses")
        .where("isActive", "==", true)
        .get();

      logger.info(`Found ${businessesSnapshot.size} active businesses to reset`);

      const batchSize = 500; // Firestore batch limit
      let batch = db.batch();
      let operationCount = 0;
      let totalReset = 0;

      for (const businessDoc of businessesSnapshot.docs) {
        const businessData = businessDoc.data();
        const businessId = businessDoc.id;

        // Archive yesterday's stats before resetting
        const todayOrders = businessData.todayOrders || 0;
        const todayEarnings = businessData.todayEarnings || 0;

        // Only archive if there was activity
        if (todayOrders > 0 || todayEarnings > 0) {
          const dailyStatsRef = db
            .collection("business_daily_stats")
            .doc(businessId)
            .collection("days")
            .doc(dateKey);

          batch.set(dailyStatsRef, {
            date: dateKey,
            orders: todayOrders,
            earnings: todayEarnings,
            archivedAt: FieldValue.serverTimestamp(),
          });
          operationCount++;
        }

        // Reset daily stats
        batch.update(businessDoc.ref, {
          todayOrders: 0,
          todayEarnings: 0,
          lastDailyReset: FieldValue.serverTimestamp(),
        });
        operationCount++;
        totalReset++;

        // Commit batch if reaching limit
        if (operationCount >= batchSize - 10) {
          await batch.commit();
          batch = db.batch();
          operationCount = 0;
          logger.info(`Committed batch, reset ${totalReset} businesses so far`);
        }
      }

      // Commit remaining operations
      if (operationCount > 0) {
        await batch.commit();
      }

      logger.info(`Daily stats reset complete. Reset ${totalReset} businesses.`);
      return null;
    } catch (error) {
      logger.error("Error resetting daily business stats:", error);
      throw error; // Retry on failure
    }
  }
);

/**
 * MONTHLY STATS RESET
 *
 * Runs on the 1st of every month at 00:05 UTC.
 * Resets monthlyEarnings for all businesses.
 *
 * Also archives the previous month's stats for historical reporting.
 */
exports.resetMonthlyBusinessStats = onSchedule(
  {
    schedule: "5 0 1 * *", // 1st of every month at 00:05 UTC
    timeZone: "UTC",
    retryCount: 3,
  },
  async (event) => {
    logger.info("Starting monthly business stats reset...");

    const lastMonth = new Date();
    lastMonth.setMonth(lastMonth.getMonth() - 1);
    const monthKey = `${lastMonth.getFullYear()}-${String(lastMonth.getMonth() + 1).padStart(2, "0")}`; // YYYY-MM

    try {
      // Get all active businesses
      const businessesSnapshot = await db
        .collection("businesses")
        .where("isActive", "==", true)
        .get();

      logger.info(`Found ${businessesSnapshot.size} active businesses for monthly reset`);

      const batchSize = 500;
      let batch = db.batch();
      let operationCount = 0;
      let totalReset = 0;

      for (const businessDoc of businessesSnapshot.docs) {
        const businessData = businessDoc.data();
        const businessId = businessDoc.id;

        // Archive last month's stats
        const monthlyEarnings = businessData.monthlyEarnings || 0;

        if (monthlyEarnings > 0) {
          const monthlyStatsRef = db
            .collection("business_monthly_stats")
            .doc(businessId)
            .collection("months")
            .doc(monthKey);

          batch.set(monthlyStatsRef, {
            month: monthKey,
            earnings: monthlyEarnings,
            totalOrders: businessData.totalOrders || 0,
            completedOrders: businessData.completedOrders || 0,
            cancelledOrders: businessData.cancelledOrders || 0,
            archivedAt: FieldValue.serverTimestamp(),
          });
          operationCount++;
        }

        // Reset monthly stats
        batch.update(businessDoc.ref, {
          monthlyEarnings: 0,
          lastMonthlyReset: FieldValue.serverTimestamp(),
        });
        operationCount++;
        totalReset++;

        // Commit batch if reaching limit
        if (operationCount >= batchSize - 10) {
          await batch.commit();
          batch = db.batch();
          operationCount = 0;
          logger.info(`Committed batch, reset ${totalReset} businesses so far`);
        }
      }

      // Commit remaining operations
      if (operationCount > 0) {
        await batch.commit();
      }

      logger.info(`Monthly stats reset complete. Reset ${totalReset} businesses.`);
      return null;
    } catch (error) {
      logger.error("Error resetting monthly business stats:", error);
      throw error;
    }
  }
);

/**
 * BUSINESS ORDER NOTIFICATION
 *
 * Triggers when a new order is created for a business.
 * Sends notification to the business owner.
 *
 * Path: business_orders/{orderId}
 */
exports.onBusinessOrderCreated = onDocumentCreated(
  "business_orders/{orderId}",
  async (event) => {
    const orderData = event.data.data();
    const orderId = event.params.orderId;

    logger.info(`New business order created: ${orderId}`);

    const businessId = orderData.businessId;
    if (!businessId) {
      logger.warn("No business ID in order, skipping notification");
      return null;
    }

    try {
      // Get business to find owner
      const businessDoc = await db.collection("businesses").doc(businessId).get();
      if (!businessDoc.exists) {
        logger.warn(`Business ${businessId} not found`);
        return null;
      }

      const businessData = businessDoc.data();
      const ownerId = businessData.userId;

      // Get owner's FCM token
      const ownerToken = await getUserFcmToken(ownerId);
      if (!ownerToken) {
        logger.warn(`No FCM token for business owner ${ownerId}`);
        return null;
      }

      // Get customer name
      const customerName = orderData.customerName || await getUserName(orderData.customerId);

      // Prepare notification
      const orderTotal = orderData.totalAmount || 0;
      const formattedTotal = new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: orderData.currency || "USD",
      }).format(orderTotal);

      await sendNotification(
        ownerToken,
        {
          title: "New Order Received!",
          body: `${customerName} placed an order for ${formattedTotal}`,
        },
        {
          type: "business_order",
          orderId: orderId,
          businessId: businessId,
          customerId: orderData.customerId || "",
          customerName: customerName,
          amount: orderTotal.toString(),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        }
      );

      logger.info(`Order notification sent to business owner ${ownerId}`);
      return null;
    } catch (error) {
      logger.error("Error sending order notification:", error);
      return null;
    }
  }
);
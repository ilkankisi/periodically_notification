const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/**
 * Scheduled Cloud Function that runs daily at specified time (Europe/Istanbul)
 * Sends daily content to all users via FCM topic
 *
 * Schedule: Every day at 02:40 AM Europe/Istanbul timezone
 * To change time, modify the schedule property below
 */
exports.sendDailyWidgetContent = onSchedule(
    {
      schedule: "40 2 * * *", // 2:40 AM daily (Europe/Istanbul timezone)
      timeZone: "Europe/Istanbul",
      memory: "256MiB",
      timeoutSeconds: 540,
    },
    async (event) => {
      const functions = require("firebase-functions");
      functions.logger.info(
          "Daily widget content scheduler triggered",
          {timestamp: new Date().toISOString()},
      );

      try {
        // Step 1: Read current state to get nextOrder
        const stateRef = db.collection("daily_state").doc("current");
        const stateDoc = await stateRef.get();

        if (!stateDoc.exists) {
          functions.logger.error("daily_state/current document not found");
          return {success: false, error: "State document not found"};
        }

        const state = stateDoc.data();
        const nextOrder = state.nextOrder || 1;

        functions.logger.info(`Looking for item with order: ${nextOrder}`);

        // Step 2: Find item with matching order (no sent filter)
        const itemsQuery = await db
            .collection("daily_items")
            .where("order", "==", nextOrder)
            .limit(1)
            .get();

        let itemDoc;
        let itemData;
        let itemId;
        let newNextOrder;

        if (itemsQuery.empty) {
          // Wrap-around: no item for nextOrder, use smallest order
          functions.logger.info(
              `No item for order ${nextOrder}, wrapping to first item`,
          );
          const fallbackQuery = await db
              .collection("daily_items")
              .orderBy("order")
              .limit(1)
              .get();
          if (fallbackQuery.empty) {
            functions.logger.error("daily_items collection is empty");
            return {
              success: false,
              error: "No items in daily_items collection",
            };
          }
          itemDoc = fallbackQuery.docs[0];
          itemData = itemDoc.data();
          itemId = itemDoc.id;
          newNextOrder = (itemData.order || 0) + 1;
        } else {
          itemDoc = itemsQuery.docs[0];
          itemData = itemDoc.data();
          itemId = itemDoc.id;
          newNextOrder = nextOrder + 1;
        }

        functions.logger.info(`Found item: ${itemId}`, {
          title: itemData.title,
          order: itemData.order,
        });

        // Step 3: Use transaction to atomically update item and state
        await db.runTransaction(async (transaction) => {
          // Update sentAt only (no sent field)
          transaction.update(itemDoc.ref, {
            sentAt: new Date(),
          });
          transaction.update(stateRef, {
            nextOrder: newNextOrder,
            lastSentAt: new Date(),
            lastSentItemId: itemId,
          });

          functions.logger.info(
              `Transaction prepared: sentAt updated, nextOrder=${newNextOrder}`,
          );
        });

        // Step 4: Prepare FCM messages
        const notificationTitle = "Günün İçeriği";
        const notificationBody = itemData.title || "Yeni içerik hazır";

        // Visible notification (guaranteed delivery)
        const notificationMessage = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            type: "DAILY_WIDGET",
            order: String(itemData.order),
            itemId: itemId,
            docPath: `daily_items/${itemId}`,
            title: itemData.title || "",
            body: itemData.body || "",
            updatedAt: new Date().toISOString(),
            imageUrl: itemData.imageUrl || "",
          },
          topic: "daily_widget_all",
          android: {
            priority: "high",
            notification: {
              channelId: "daily_widget_channel",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: notificationTitle,
                  body: notificationBody,
                },
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        // Optional: Silent data-only message for widget auto-update
        const dataOnlyMessage = {
          data: {
            type: "DAILY_WIDGET_UPDATE",
            order: String(itemData.order),
            itemId: itemId,
            docPath: `daily_items/${itemId}`,
            title: itemData.title || "",
            body: itemData.body || "",
            updatedAt: new Date().toISOString(),
            imageUrl: itemData.imageUrl || "",
          },
          topic: "daily_widget_all",
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "5", // Low priority for silent notification
            },
            payload: {
              aps: {
                "content-available": 1,
              },
            },
          },
        };

        // Step 5: Send both messages
        const results = await Promise.allSettled([
          messaging.send(notificationMessage),
          messaging.send(dataOnlyMessage),
        ]);

        const notificationResult = results[0];
        const dataOnlyResult = results[1];

        if (notificationResult.status === "fulfilled") {
          functions.logger.info(
              "Visible notification sent successfully",
              {messageId: notificationResult.value},
          );
        } else {
          functions.logger.error(
              "Failed to send visible notification",
              {error: notificationResult.reason},
          );
        }

        if (dataOnlyResult.status === "fulfilled") {
          functions.logger.info(
              "Data-only message sent successfully",
              {messageId: dataOnlyResult.value},
          );
        } else {
          functions.logger.warn(
              "Failed to send data-only message (non-critical)",
              {error: dataOnlyResult.reason},
          );
        }

        return {
          success: true,
          itemId: itemId,
          order: itemData.order,
          notificationSent: notificationResult.status === "fulfilled",
          dataOnlySent: dataOnlyResult.status === "fulfilled",
        };
      } catch (error) {
        functions.logger.error("Error in sendDailyWidgetContent", {
          error: error.message,
          stack: error.stack,
        });
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

/**
 * Helper function to manually trigger daily content send (for testing)
 * GET/POST: http://127.0.0.1:5001/periodically-notification/us-central1/manualSendDailyContent
 */
exports.manualSendDailyContent = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      const functions = require("firebase-functions");
      const logger = require("firebase-functions/logger");
      logger.info("Manual send triggered");

      // Reuse the same logic as scheduled function
      // For simplicity, we'll call the scheduled function logic inline
      // In production, extract to a shared function

      try {
        const stateRef = db.collection("daily_state").doc("current");
        const stateDoc = await stateRef.get();

        if (!stateDoc.exists) {
          res.status(404).json({success: false, error: "State document not found"});
          return;
        }

        const state = stateDoc.data();
        const nextOrder = state.nextOrder || 1;

        const itemsQuery = await db
            .collection("daily_items")
            .where("order", "==", nextOrder)
            .limit(1)
            .get();

        let itemDoc;
        let itemData;
        let itemId;
        let newNextOrder;

        if (itemsQuery.empty) {
          const fallbackQuery = await db
              .collection("daily_items")
              .orderBy("order")
              .limit(1)
              .get();
          if (fallbackQuery.empty) {
            res.status(404).json({
              success: false,
              error: "No items in daily_items collection",
            });
            return;
          }
          itemDoc = fallbackQuery.docs[0];
          itemData = itemDoc.data();
          itemId = itemDoc.id;
          newNextOrder = (itemData.order || 0) + 1;
        } else {
          itemDoc = itemsQuery.docs[0];
          itemData = itemDoc.data();
          itemId = itemDoc.id;
          newNextOrder = nextOrder + 1;
        }

        await db.runTransaction(async (transaction) => {
          transaction.update(itemDoc.ref, {
            sentAt: new Date(),
          });
          transaction.update(stateRef, {
            nextOrder: newNextOrder,
            lastSentAt: new Date(),
            lastSentItemId: itemId,
          });
        });

        const notificationMessage = {
          notification: {
            title: "Günün İçeriği",
            body: itemData.title || "Yeni içerik hazır",
          },
          data: {
            type: "DAILY_WIDGET",
            order: String(itemData.order),
            itemId: itemId,
            docPath: `daily_items/${itemId}`,
            title: itemData.title || "",
            body: itemData.body || "",
            updatedAt: new Date().toISOString(),
            imageUrl: itemData.imageUrl || "",
          },
          topic: "daily_widget_all",
        };

        const messageId = await messaging.send(notificationMessage);

        res.status(200).json({
          success: true,
          itemId: itemId,
          order: itemData.order,
          messageId: messageId,
        });
      } catch (error) {
        logger.error("Error in manualSendDailyContent", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    },
);

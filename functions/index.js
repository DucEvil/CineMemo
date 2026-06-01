const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.sendShowtimeReminders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Ho_Chi_Minh",
    region: "asia-southeast1",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db
      .collection("showtimeReminders")
      .where("status", "==", "pending")
      .where("scheduledFor", "<=", now)
      .limit(100)
      .get();

    if (snapshot.empty) {
      logger.info("No reminder jobs to process.");
      return;
    }

    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      const tokens = Array.isArray(data.targetTokens)
        ? data.targetTokens
            .filter((token) => typeof token === "string")
            .map((token) => token.trim())
            .filter((token) => token.length > 0)
        : [];

      if (tokens.length === 0) {
        await doc.ref.update({
          status: "failed",
          error: "No target FCM token.",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        continue;
      }

      const title =
        typeof data.title === "string" && data.title.trim().length > 0
          ? data.title.trim()
          : "Nhac lich xem phim";

      const body =
        typeof data.body === "string" && data.body.trim().length > 0
          ? data.body.trim()
          : `${data.movieTitle || "Phim"} se chieu sau 30 phut tai ${
              data.theaterName || "rap phim"
            }`;

      try {
        const result = await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title,
            body,
          },
          data: {
            type: "showtime_reminder",
            bookingId: String(data.bookingId || doc.id),
            movieTitle: String(data.movieTitle || ""),
            theaterName: String(data.theaterName || ""),
          },
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
          },
        });

        const invalidTokens = [];
        result.responses.forEach((response, index) => {
          if (response.success) {
            return;
          }

          const code = response.error?.code || "";
          if (
            code.includes("registration-token-not-registered") ||
            code.includes("invalid-registration-token")
          ) {
            invalidTokens.push(tokens[index]);
          }
        });

        const updatePayload = {
          status: result.successCount > 0 ? "sent" : "failed",
          successCount: result.successCount,
          failureCount: result.failureCount,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (invalidTokens.length > 0) {
          updatePayload.invalidTokens = invalidTokens;
          const userId = typeof data.userId === "string" ? data.userId : "";
          if (userId) {
            await db
              .collection("users")
              .doc(userId)
              .set(
                {
                  fcmTokens: admin.firestore.FieldValue.arrayRemove(
                    ...invalidTokens
                  ),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
                { merge: true }
              );
          }
        }

        await doc.ref.update(updatePayload);
      } catch (error) {
        logger.error("Failed to send showtime reminder", {
          reminderId: doc.id,
          error,
        });

        await doc.ref.update({
          status: "failed",
          error: String(error),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }
);

const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const nodemailer = require("nodemailer");
const functions = require('firebase-functions');
const { logger } = require('firebase-functions');
const momoHandlers = require("./momo");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const { GoogleAuth } = require('google-auth-library');
const ga = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });

// Export MoMo payment functions
exports.createMomoPayment = momoHandlers.createMomoPayment;
exports.checkMomoPayment = momoHandlers.checkMomoPayment;

// Cached Zoho config
let zohoConfigCache = null;
let configCacheTime = 0;
const CONFIG_CACHE_TTL = 60000; // 1 minute

// Get Zoho configuration from Firestore
async function getZohoConfig() {
  const now = Date.now();
  if (zohoConfigCache && now - configCacheTime < CONFIG_CACHE_TTL) {
    return zohoConfigCache;
  }

  try {
    const doc = await db.collection("config").doc("zohoEmail").get();
    if (doc.exists) {
      zohoConfigCache = doc.data();
      configCacheTime = now;
      return zohoConfigCache;
    }
  } catch (error) {
    logger.error("Error reading Zoho config from Firestore:", error);
  }

  // Fallback to environment variables or defaults
  return {
    smtpHost: process.env.ZOHO_SMTP_HOST || "smtppro.zoho.com",
    smtpPort: parseInt(process.env.ZOHO_SMTP_PORT || "465", 10),
    smtpUsername: process.env.ZOHO_SMTP_USERNAME || "",
    smtpPassword: process.env.ZOHO_SMTP_PASSWORD || "",
    senderName: process.env.ZOHO_SENDER_NAME || "CineMemo",
    senderEmail: process.env.ZOHO_SENDER_EMAIL || process.env.ZOHO_SMTP_USERNAME || "",
  };
}

// Helper to log presence of Zoho config without exposing secrets
function logZohoConfigPresence(cfg) {
  try {
    const usernameSet = !!(cfg && cfg.smtpUsername);
    const passwordSet = !!(cfg && cfg.smtpPassword);
    const senderEmailSet = !!(cfg && cfg.senderEmail);
    logger.info('Zoho config presence', {
      smtpHost: cfg && cfg.smtpHost,
      smtpPort: cfg && cfg.smtpPort,
      usernameSet,
      passwordSet,
      senderEmailSet,
    });
  } catch (e) {
    // swallow logging errors
  }
}

async function sendZohoEmail({ to, subject, html }) {
  const config = await getZohoConfig();
  const { smtpHost, smtpPort, smtpUsername, smtpPassword, senderName, senderEmail } = config;

  if (!smtpUsername || !smtpPassword) {
    throw new Error("Zoho SMTP is not configured. Please set config/zohoEmail in Firestore.");
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: {
      user: smtpUsername,
      pass: smtpPassword,
    },
  });

  const info = await transporter.sendMail({
    from: `${senderName} <${senderEmail}>`,
    to,
    subject,
    html,
  });

  return info;
}


exports.sendTicketEmail = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send({ error: "Method not allowed" });
    return;
  }

  // Log Zoho config presence for debugging (safe: does not expose secrets)
  try {
    const cfg = await getZohoConfig();
    logZohoConfigPresence(cfg);
  } catch (e) {
    logger.warn('Failed to read Zoho config for logging', e);
  }

  const payload = req.body || {};
  const recipientEmail = String(payload.recipientEmail || "").trim();
  const bookingId = String(payload.bookingId || "");
  const ticketCode = String(payload.ticketCode || "");
  const qrPayload = String(payload.qrPayload || "");
  const movieTitle = String(payload.movieTitle || "");
  const theaterName = String(payload.theaterName || "");
  const showtimeLabel = String(payload.showtimeLabel || "");
  const seats = Array.isArray(payload.seats)
    ? payload.seats.map(String)
    : [];
  const totalPrice = Number(payload.totalPrice || 0);
  const showStartAt = payload.showStartAt ? new Date(payload.showStartAt) : null;

  if (!recipientEmail) {
    res.status(400).send({ error: "recipientEmail is required" });
    return;
  }

  if (!bookingId || !ticketCode) {
    res.status(400).send({ error: "bookingId and ticketCode are required" });
    return;
  }

  const showtimeText = showStartAt
    ? new Date(showStartAt).toLocaleString("vi-VN", {
        hour: "2-digit",
        minute: "2-digit",
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
      })
    : showtimeLabel;

  const seatLabel = seats.length > 0 ? seats.join(", ") : "Chưa xác định";
  const barcodeUrl =
    "https://bwipjs-api.metafloor.com/?bcid=code128&includetext&scale=3&text=" +
    encodeURIComponent(ticketCode);
  const qrUrl =
    "https://quickchart.io/qr?size=220&text=" +
    encodeURIComponent(qrPayload);

  const html = `
<div style="font-family:Arial,sans-serif;line-height:1.6;color:#0f172a;">
  <h2 style="margin:0 0 10px;">Vé điện tử CineMemo</h2>
  <p style="margin:0 0 12px;">Cảm ơn bạn đã đặt vé. Đây là thông tin vé của bạn:</p>
  <ul style="padding-left:18px;margin:0 0 12px;">
    <li><strong>Mã đặt vé:</strong> ${bookingId}</li>
    <li><strong>Mã vé:</strong> ${ticketCode}</li>
    <li><strong>Phim:</strong> ${movieTitle}</li>
    <li><strong>Rạp:</strong> ${theaterName}</li>
    <li><strong>Suất chiếu:</strong> ${showtimeText}</li>
    <li><strong>Ghế:</strong> ${seatLabel}</li>
    <li><strong>Tổng tiền:</strong> ${totalPrice.toString()}</li>
  </ul>
  <p style="margin:12px 0 6px;"><strong>Mã vạch vé:</strong></p>
  <img src="${barcodeUrl}" alt="ticket barcode" style="max-width:100%;height:auto;border:1px solid #e2e8f0;padding:6px;background:#ffffff;" />
  <p style="margin:12px 0 6px;"><strong>Mã QR check-in:</strong></p>
  <img src="${qrUrl}" alt="ticket qr" style="max-width:220px;height:auto;border:1px solid #e2e8f0;padding:6px;background:#ffffff;" />
</div>
`;

  try {
    const info = await sendZohoEmail({
      to: recipientEmail,
      subject: `Vé xem phim ${movieTitle} - CineMemo`,
      html,
    });

    res.status(200).send({
      success: true,
      message: "Email vé đã được gửi.",
      info,
    });
  } catch (error) {
    logger.error("Failed to send Zoho email", { error });
    res.status(500).send({
      success: false,
      message: "Gửi email thất bại.",
      error: String(error),
    });
  }
});

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

// Deprecated: Using Firebase Generative AI Extension instead
// Extension automatically handles prompt updates in 'generate' collection
// and writes responses back to the same document
/*
exports.onAiRequestCreate = functions.firestore
  .document('aiRequests/{reqId}')
  .onCreate(async (snap, ctx) => {
    const data = snap.data() || {};
    const conversationId = data.conversationId;
    const requestId = snap.id;

    try {
      if (!conversationId) {
        throw new Error('aiRequest missing conversationId');
      }

      // build prompt from conversation messages (limit last 20 messages)
      const msgsSnap = await db
        .collection(`aiConversations/${conversationId}/messages`)
        .orderBy('createdAt', 'asc')
        .get();

      const all = msgsSnap.docs.map(d => d.data()).filter(Boolean);
      const recent = all.slice(-20);
      const prompt = recent.map(m => `${m.role}: ${m.text}`).join('\n');

      // get bearer token via google-auth-library (service account)
      const client = await ga.getClient();
      const accessToken = await client.getAccessToken();
      const bearer = accessToken.token || accessToken;

      const MODEL =
        String(data.modelOverride || process.env.GENERATIVE_MODEL || 'models/gemini-1.0').trim();
      const url = `https://generativelanguage.googleapis.com/v1beta2/${MODEL}:generate`;
      logger.info('Calling Gemini API', { model: MODEL, url });

      const body = {
        prompt: { text: prompt },
      };

      const res = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${bearer}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });

      const status = res.status;
      const headersObj = {};
      try {
        res.headers.forEach((v, k) => (headersObj[k] = v));
      } catch (e) {}

      const responseText = await res.text();
      let json = null;
      try {
        if (responseText && responseText.trim().length > 0) json = JSON.parse(responseText);
      } catch (parseErr) {
        logger.error('Failed to parse Generative API response JSON', { parseErr: String(parseErr), status, textSnippet: responseText ? responseText.slice(0, 1000) : '' });
      }

      if (!json && (!responseText || responseText.trim().length === 0)) {
        throw new Error(`Empty or non-JSON response from Generative API (status=${status})`);
      }

      const assistantText =
        (json && json?.candidates && json.candidates[0]?.content) ||
        (json && json?.output && json.output[0]?.content) ||
        responseText;

      await db
        .collection(`aiConversations/${conversationId}/messages`)
        .add({
          role: 'assistant',
          text: assistantText,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      await snap.ref.update({
        status: 'done',
        assistantText,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      logger.error('onAiRequestCreate error', err);
      try {
        await snap.ref.update({
          status: 'failed',
          error: String(err),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  });
*/

// Expose MoMo endpoints (createMomoPayment, checkMomoPayment already exported at top)

// Deprecated: Using Firebase Extension now
// Test helper: create a conversation + user message + aiRequest to trigger processing
/*
exports.testCreateConversation = onRequest(async (req, res) => {
  try {
    const convId = req.query.id || db.collection('aiConversations').doc().id;
    const convRef = db.collection('aiConversations').doc(convId);
    await convRef.set({ conversationId: convId, createdAt: admin.firestore.FieldValue.serverTimestamp() });

    await convRef.collection('messages').add({
      role: 'user',
      text: String(req.query.text || 'Xin chào từ test!'),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const requestDoc = db.collection('aiRequests').doc();
    await requestDoc.set({
      requestId: requestDoc.id,
      requestType: 'conversation',
      userId: 'test-client',
      conversationId: convId,
      status: 'pending',
      modelOverride: String(req.query.model || '').trim() || undefined,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(200).send({ ok: true, conversationId: convId, requestId: requestDoc.id });
  } catch (err) {
    logger.error('testCreateConversation error', err);
    res.status(500).send({ ok: false, error: String(err) });
  }
});
*/


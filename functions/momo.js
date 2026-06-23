const axios = require('axios');
const crypto = require('crypto');
const { onRequest } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const config = require('./config');

// Get MoMo config from config.js
function getMomoConfig() {
  return {
    partnerCode: process.env.MOMO_PARTNER_CODE || config.momo.partnerCode || '',
    accessKey: process.env.MOMO_ACCESS_KEY || config.momo.accessKey || '',
    secretKey: process.env.MOMO_SECRET_KEY || config.momo.secretKey || '',
    createEndpoint: process.env.MOMO_CREATE_ENDPOINT || config.momo.createEndpoint,
    queryEndpoint: process.env.MOMO_QUERY_ENDPOINT || config.momo.queryEndpoint,
  };
}

function sign(raw, secret) {
  return crypto.createHmac('sha256', secret).update(raw).digest('hex');
}

// Cloud Function v2: Create MoMo Payment
exports.createMomoPayment = onRequest(
  { cors: true },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send({ error: 'Method not allowed' });
      return;
    }

    const cfg = getMomoConfig();
    const { partnerCode, accessKey, secretKey } = cfg;

    if (!partnerCode || !accessKey || !secretKey) {
      logger.error('Momo credentials not configured', {
        partnerCodeSet: !!partnerCode,
        accessKeySet: !!accessKey,
        secretKeySet: !!secretKey,
      });
      res.status(500).send({ error: 'Momo credentials not configured on server' });
      return;
    }

    const body = req.body || {};
    const orderId = String(body.orderId || '');
    const amount = Number(body.amount || 0);
    const orderInfo = String(body.orderInfo || '');
    const redirectUrl = String(body.redirectUrl || '');
    const ipnUrl = String(body.ipnUrl || process.env.MOMO_IPN_URL || '');

    logger.info('Received createMomoPayment request', {
      orderId,
      amount,
      orderInfoLength: orderInfo.length,
      redirectUrl,
      ipnUrlProvided: !!body.ipnUrl,
      ipnUrlUsed: !!ipnUrl,
    });

    if (!orderId || !amount || !orderInfo || !redirectUrl || !ipnUrl) {
      res.status(400).send({
        error:
          'Missing required fields: orderId, amount, orderInfo, redirectUrl, ipnUrl',
        details: {
          orderId: !!orderId,
          amount: amount > 0,
          orderInfo: !!orderInfo,
          redirectUrl: !!redirectUrl,
          ipnUrl: !!ipnUrl,
        },
      });
      return;
    }

    const requestId = String(Date.now());
    const extraData = '';
    const requestType = 'payWithMethod';

    const raw = `accessKey=${accessKey}&amount=${amount}&extraData=${extraData}&ipnUrl=${ipnUrl}&orderId=${orderId}&orderInfo=${orderInfo}&partnerCode=${partnerCode}&redirectUrl=${redirectUrl}&requestId=${requestId}&requestType=${requestType}`;
    const signature = sign(raw, secretKey);

    const payload = {
      partnerCode,
      accessKey,
      requestId,
      amount: String(amount),
      orderId,
      orderInfo,
      redirectUrl,
      ipnUrl,
      requestType,
      extraData,
      signature,
    };

    logger.info('Sending Momo create request', {
      endpoint: cfg.createEndpoint,
      orderId,
      amount,
      ipnUrl,
      signature: signature.substring(0, 10) + '...',
    });

    try {
      const r = await axios.post(cfg.createEndpoint, payload, { timeout: 15000 });
      const data = r.data || {};

      if (data.resultCode !== 0) {
        logger.warn('Momo create returned non-zero resultCode', { resultCode: data.resultCode });
        res.status(400).send({ error: 'Momo create failed', data });
        return;
      }

      res.status(200).send({
        payUrl: data.payUrl,
        qrCodeUrl: data.qrCodeUrl,
        deeplink: data.deeplink,
        data,
        requestId,
      });
    } catch (e) {
      logger.error('Failed to call Momo create endpoint', {
        error: e.message,
        endpoint: cfg.createEndpoint,
        status: e.response?.status,
        response: e.response?.data,
      });
      res.status(502).send({ error: 'Failed to contact Momo gateway', detail: String(e.message) });
    }
  }
);

// Cloud Function v2: Check MoMo Payment Status
exports.checkMomoPayment = onRequest(
  { cors: true },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).send({ error: 'Method not allowed' });
      return;
    }

    const cfg = getMomoConfig();
    const { partnerCode, accessKey, secretKey } = cfg;
    if (!partnerCode || !accessKey || !secretKey) {
      logger.error('Momo credentials not configured', {
        partnerCodeSet: !!partnerCode,
        accessKeySet: !!accessKey,
        secretKeySet: !!secretKey,
      });
      res.status(500).send({ error: 'Momo credentials not configured on server' });
      return;
    }

    const body = req.body || {};
    const orderId = String(body.orderId || '');
    const requestId = String(body.requestId || Date.now());

    if (!orderId) {
      res.status(400).send({ error: 'Missing required field: orderId' });
      return;
    }

    const raw = `accessKey=${accessKey}&orderId=${orderId}&partnerCode=${partnerCode}&requestId=${requestId}`;
    const signature = sign(raw, secretKey);

    const payload = {
      partnerCode,
      accessKey,
      requestId,
      orderId,
      signature,
    };

    try {
      const r = await axios.post(cfg.queryEndpoint, payload, { timeout: 15000 });
      const data = r.data || {};
      res.status(200).send(data);
    } catch (e) {
      logger.error('Failed to call Momo query endpoint', {
        error: e.message,
        endpoint: cfg.queryEndpoint,
      });
      res.status(502).send({ error: 'Failed to contact Momo gateway', detail: String(e.message) });
    }
  }
);

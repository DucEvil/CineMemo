// MoMo Configuration
// TODO: Migrate to Google Cloud Secret Manager before production
module.exports = {
  momo: {
    partnerCode: 'MOMO',
    accessKey: 'F8BBA842ECF85',
    secretKey: 'K951B6PE1waDMi640xX08PD3vg6EkVlz',
    createEndpoint: 'https://test-payment.momo.vn/v2/gateway/api/create',
    queryEndpoint: 'https://test-payment.momo.vn/v2/gateway/api/query',
  },
};

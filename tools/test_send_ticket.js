const https = require('https');

const recipient = process.env.RECIPIENT || 'youremail@example.com';

const payload = JSON.stringify({
  recipientEmail: recipient,
  bookingId: 'B123',
  ticketCode: 'T123',
  qrPayload: 'payload',
  movieTitle: 'Test Movie',
  theaterName: 'Test Theater',
  showtimeLabel: '20:00',
  seats: ['A1'],
  totalPrice: 100000,
});

const options = {
  hostname: 'sendticketemail-oyl5qwczfa-uc.a.run.app',
  port: 443,
  path: '/sendTicketEmail',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  },
};

const req = https.request(options, (res) => {
  console.log(`STATUS: ${res.statusCode}`);
  console.log('HEADERS:', res.headers);
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log('BODY:', data);
  });
});

req.on('error', (e) => { console.error('REQUEST ERROR:', e); });
req.write(payload);
req.end();

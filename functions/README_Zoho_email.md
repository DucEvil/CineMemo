Zoho email Cloud Function setup

1) Install function dependencies:

```bash
cd functions
npm install
```

2) Set Zoho SMTP environment variables for Firebase Functions using your email `doduc2311@nhom6ca4.nhom6ca465httt.page`:

```bash
firebase functions:config:set zoho.smtp_host="smtppro.zoho.com" \
  zoho.smtp_port="465" \
  zoho.smtp_username="doduc2311@nhom6ca4.nhom6ca465httt.page" \
  zoho.smtp_password="17EmXRQtfm1J" \
  zoho.sender_name="CineMemo" \
  zoho.sender_email="doduc2311@nhom6ca4.nhom6ca465httt.page"
```

Replace `YOUR_ZOHO_PASSWORD` with your Zoho mail password.

3) Deploy functions:

```bash
cd functions
npm run deploy
```

4) After deployment, copy the function URL and set it as an environment variable in your Flutter app:

The function URL will be: `https://<region>-<project>.cloudfunctions.net/sendTicketEmail`

Build your Flutter app with:

```bash
flutter build web --release \
  --dart-define=TICKET_EMAIL_FUNCTION_URL="https://<region>-<project>.cloudfunctions.net/sendTicketEmail"
```

5) Deploy web app to Firebase Hosting:

```bash
firebase deploy --only hosting
```

Example payload sent to the function:

```json
{
  "recipientEmail": "user@example.com",
  "bookingId": "B123",
  "ticketCode": "TICKET123",
  "qrPayload": "https://example.com/qr/abc",
  "movieTitle": "Phim Demo",
  "theaterName": "CineMemo",
  "showtimeLabel": "20:00 01/01/2026",
  "seats": ["A1", "A2"],
  "totalPrice": 150000
}
```

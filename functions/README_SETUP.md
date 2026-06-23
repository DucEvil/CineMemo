# Firebase Cloud Functions Setup Guide for Email Delivery

## Overview
The `sendTicketEmail` Cloud Function sends ticket emails via Zoho SMTP. The function reads configuration from Firestore (with fallback to environment variables).

## Setup Instructions

### Step 1: Configure Zoho Email in Firestore

Add the Zoho configuration to your Firestore database:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **cinememo-app**
3. Go to **Firestore Database**
4. Create a new collection called **config** (if it doesn't exist)
5. In the **config** collection, create a document with ID: **zohoEmail**
6. Add the following fields:

```
Document: config/zohoEmail

Fields:
- smtpHost: "smtppro.zoho.com" (String)
- smtpPort: 465 (Number)
- smtpUsername: "doduc2311@nhom6ca4.nhom6ca465httt.page" (String)
- smtpPassword: "17EmXRQtfm1J" (String) [IMPORTANT: Use a strong password]
- senderName: "CineMemo" (String)
- senderEmail: "doduc2311@nhom6ca4.nhom6ca465httt.page" (String)
```

### Step 2: Secure the Configuration (Optional but Recommended)

Update your Firestore security rules to restrict access to the config collection:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing rules ...
    
    // Restrict config collection to Firebase Functions only
    match /config/{document=**} {
      allow read, write: if request.auth.uid != null && request.auth.token.firebase.sign_in_provider == 'anonymous';
      // For production, consider using Service Account authentication
    }
  }
}
```

### Step 3: Deploy Cloud Functions

The functions have already been deployed. To redeploy with changes:

```bash
cd functions
npm run deploy
```

### Step 4: Add Function URL to Your Web App

After deployment, the function will be available at:
```
https://us-central1-cinememo-app.cloudfunctions.net/sendTicketEmail
```

Update your Flutter web app config with this URL:

**In lib/config/app_config.dart:**
```dart
static const String ticketEmailFunctionUrl = 
  'https://us-central1-cinememo-app.cloudfunctions.net/sendTicketEmail';
```

### Step 5: Build and Deploy Web App

```bash
flutter build web --release --dart-define=TICKET_EMAIL_FUNCTION_URL="https://us-central1-cinememo-app.cloudfunctions.net/sendTicketEmail"
firebase deploy --only hosting
```

## Function Endpoint

**HTTP Method:** POST

**URL:** `https://us-central1-cinememo-app.cloudfunctions.net/sendTicketEmail`

**Request Body (JSON):**
```json
{
  "recipientEmail": "user@example.com",
  "bookingId": "booking123",
  "ticketCode": "TICKET-CODE-12345",
  "qrPayload": "booking123|TICKET-CODE-12345",
  "movieTitle": "Movie Name",
  "theaterName": "Theater Name",
  "showtimeLabel": "14:30 - 16:30",
  "seats": ["A1", "A2"],
  "totalPrice": 250000,
  "showStartAt": "2025-01-15T14:30:00Z"
}
```

**Response:**
- Success (200): `{ "message": "Email sent successfully", "info": {...} }`
- Error (400/500): `{ "error": "Error message" }`

## Testing

Test the function using curl:

```bash
curl -X POST https://us-central1-cinememo-app.cloudfunctions.net/sendTicketEmail \
  -H "Content-Type: application/json" \
  -d '{
    "recipientEmail": "test@example.com",
    "bookingId": "test-123",
    "ticketCode": "TEST-TICKET",
    "qrPayload": "test|TEST-TICKET",
    "movieTitle": "Test Movie",
    "theaterName": "Test Theater",
    "showtimeLabel": "14:00 - 16:00",
    "seats": ["A1"],
    "totalPrice": 100000,
    "showStartAt": "2025-01-20T14:00:00Z"
  }'
```

## Troubleshooting

### Function not found
- Verify deployment completed successfully
- Check Firebase Console > Cloud Functions for the function status

### Email not sending
1. Check the function logs in Firebase Console
2. Verify Firestore config document exists at `config/zohoEmail`
3. Verify Zoho SMTP credentials are correct
4. Check if Zoho account is active

### Logs Location
- Firebase Console > Cloud Functions > sendTicketEmail > Logs
- Or in Cloud Logging: `resource.type="cloud_function" AND resource.labels.function_name="sendTicketEmail"`

## Notes

- The function caches Firestore config for 1 minute to reduce reads
- First deployment may take 2-3 minutes
- Email template includes QR code and barcode images
- All timestamps are displayed in Vietnamese locale (vi-VN)

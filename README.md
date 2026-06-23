# CineMemo

Flutter app for movie discovery and booking.

## FCM Reminder Flow (30 Minutes Before Showtime)

This project uses Firebase Cloud Messaging (FCM) with Firestore + Cloud Functions
to push reminders 30 minutes before showtime.

Flow summary:

1. User completes booking.
2. App requests FCM permission and gets device token.
3. App writes a reminder job to `showtimeReminders/{bookingId}` in Firestore.
4. Scheduled Cloud Function (`sendShowtimeReminders`) runs every minute.
5. Function sends FCM push when `scheduledFor <= now`.

## MoMo Sandbox Payment (Deep Link Callback)

The app now uses `momo_payment_flutter` in sandbox mode and waits for the
deep-link callback before finishing checkout.

Required Dart define values:

- `MOMO_MERCHANT_CODE`
- `MOMO_ACCESS_KEY`
- `MOMO_SECRET_KEY`
- `MOMO_PAYMENT_MODE=gateway`
- `MOMO_SANDBOX_MODE=true`
- `MOMO_APP_SCHEME=cinememo`
- `MOMO_CALLBACK_HOST=payment-callback`
- `MOMO_IPN_URL=https://your-server.com/momo-ipn`

## MoMo Personal QR Mode (Simple / Emulator)

If you only need a simple flow using your personal MoMo account, set:

- `MOMO_PAYMENT_MODE=personal_qr`

In this mode, the app shows your QR/transfer info and lets users confirm
payment manually (no gateway API call, no deep-link callback required).

Important:

- Android deep-link filter is configured for `cinememo://payment-callback`.
- iOS URL scheme is configured as `cinememo`.
- If you change `MOMO_APP_SCHEME` or `MOMO_CALLBACK_HOST`, update Android and
	iOS native config to match.

## Setup

### 1) Flutter dependencies

```bash
flutter pub get
```

### 2) Functions dependencies

```bash
cd functions
npm install
cd ..
```

### 3) Deploy Firestore rules and Cloud Function

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions:sendShowtimeReminders
```

### 4) Run app

```bash
# Use the deployed Cloud Function URL for ticket email sending.
flutter run --dart-define=TICKET_EMAIL_FUNCTION_URL="https://<region>-<project>.cloudfunctions.net/sendTicketEmail"

# Chrome
flutter run -d chrome --dart-define=TICKET_EMAIL_FUNCTION_URL="https://<region>-<project>.cloudfunctions.net/sendTicketEmail"
```


###Payment
//Thành công
Card: 9704000000000018
Name: NGUYEN VAN A
Exp: 03/07
OTP: OTP
//Nguồn tiền không đủ
NGUYEN VAN A
9704 0000 0000 0034
03/07
OTP	

## Notes

- Android already includes `POST_NOTIFICATIONS` in `AndroidManifest.xml`.
- For iOS push delivery, APNs key/certificate must be configured in Firebase Console.
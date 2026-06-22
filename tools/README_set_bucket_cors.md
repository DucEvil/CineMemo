Setup and run instructions for `set_bucket_cors.js`

1) Install dependencies (Node.js required):

```bash
npm install @google-cloud/storage
```

2) Run using the service account file included in the repo (example):

```bash
# from repo root
node tools/set_bucket_cors.js backend/secrets/firebase-service-account.json cinememo-app.appspot.com
```

Replace `cinememo-app.appspot.com` with your actual bucket name if different. You can find the bucket name in `lib/config/firebase_options.dart` under `storageBucket`.

3) Alternatively set `GOOGLE_APPLICATION_CREDENTIALS` and run with just the bucket name:

```bash
set GOOGLE_APPLICATION_CREDENTIALS=backend\secrets\firebase-service-account.json
node tools/set_bucket_cors.js cinememo-app.appspot.com
```

4) After running, hard-refresh the page (DevTools Network -> Disable cache) and retry uploads from `http://localhost:8080`.
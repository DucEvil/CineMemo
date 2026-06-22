#!/usr/bin/env node
// Usage:
// 1) With explicit key file:
//    node tools/set_bucket_cors.js path/to/service-account.json your-bucket-name
// 2) Or set GOOGLE_APPLICATION_CREDENTIALS env var and run:
//    node tools/set_bucket_cors.js your-bucket-name
// This script sets CORS on the given GCS bucket to allow requests from localhost and production origin.
const {Storage} = require('@google-cloud/storage');
const path = require('path');

async function main() {
  const args = process.argv.slice(2);
  let keyFile;
  let bucketName;

  if (args.length === 2) {
    keyFile = path.resolve(args[0]);
    bucketName = args[1];
  } else if (args.length === 1) {
    keyFile = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    bucketName = args[0];
  } else {
    keyFile = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    bucketName = process.env.FIREBASE_BUCKET || process.env.GCLOUD_BUCKET;
  }

  if (!bucketName) {
    console.error('Error: bucket name is required. Usage: node tools/set_bucket_cors.js /path/to/key.json your-bucket-name');
    process.exit(1);
  }

  const storageOptions = {};
  if (keyFile) storageOptions.keyFilename = keyFile;

  const storage = new Storage(storageOptions);
  const bucket = storage.bucket(bucketName);

  const cors = [
    {
      origin: [
        'http://localhost:8080',
        'http://localhost:5000',
        'https://cinememo-app.web.app',
        'https://nhom6ca4.nhom6ca465httt.page'
      ],
      method: ['GET', 'HEAD', 'PUT', 'POST', 'DELETE', 'OPTIONS'],
      responseHeader: ['Content-Type', 'Access-Control-Allow-Origin', 'x-goog-resumable', 'Authorization'],
      maxAgeSeconds: 3600,
    },
  ];

  try {
    console.log(`Setting CORS on bucket: ${bucketName}`);
    await bucket.setMetadata({cors});
    console.log('CORS configuration applied successfully. New CORS:');
    const [metadata] = await bucket.getMetadata();
    console.log(JSON.stringify(metadata.cors, null, 2));
    console.log('Now retry your upload from http://localhost:8080');
  } catch (err) {
    console.error('Failed to set CORS:', err.message || err);
    process.exit(2);
  }
}

main();

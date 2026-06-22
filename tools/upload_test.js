const {Storage} = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');

async function main() {
  const keyPath = path.join(__dirname, '..', 'backend', 'secrets', 'firebase-service-account.json');
  if (!fs.existsSync(keyPath)) {
    console.error('Service account JSON not found at', keyPath);
    process.exit(1);
  }

  const storage = new Storage({keyFilename: keyPath});
  const bucketName = 'cinememo-app.firebasestorage.app';
  const bucket = storage.bucket(bucketName);

  const tmpFile = path.join(__dirname, 'test-upload.txt');
  fs.writeFileSync(tmpFile, `Test upload at ${new Date().toISOString()}`);
  const dest = `cinememo/tests/${path.basename(tmpFile)}`;

  console.log('Uploading', tmpFile, 'to', `${bucketName}/${dest}`);
  await bucket.upload(tmpFile, {destination: dest});
  console.log('Upload complete.');

  fs.unlinkSync(tmpFile);
  process.exit(0);
}

main().catch(err => {
  console.error('Upload failed:', err);
  process.exit(2);
});

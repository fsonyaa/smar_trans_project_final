const https = require('https');
const fs = require('fs');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const token = config.tokens.access_token;

function updatePassword(uid, password) {
  return new Promise((resolve, reject) => {
    // Format attendu par l'API identitytoolkit v1 accounts:update
    const body = JSON.stringify({
      localId: uid,
      password: password
    });

    const options = {
      hostname: 'identitytoolkit.googleapis.com',
      path: '/v1/accounts:update',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let responseBody = '';
      res.on('data', chunk => responseBody += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`Password updated successfully for UID: ${uid}`);
          resolve(JSON.parse(responseBody));
        } else {
          console.error(`Failed to update password for ${uid}:`, res.statusCode, responseBody);
          reject(new Error(responseBody));
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function run() {
  try {
    await updatePassword('7ozFSpO5bohUwUPuieCP5of7BB92', 'admin123');
  } catch(e) {}
  
  try {
    await updatePassword('vOhtCMPzA3UDFxHzdSuNHLC1aMt1', 'admin123');
  } catch(e) {}
}

run();

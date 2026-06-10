const https = require('https');
const fs = require('fs');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const token = config.tokens.access_token;
const project = 'smart-trans-dc828';

// API Google Identity Toolkit pour créer ou mettre à jour un utilisateur avec un mot de passe en clair
function setPassword(email, password, localId) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      users: [
        {
          localId: localId,
          email: email,
          password: password
        }
      ]
    });

    const options = {
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/projects/${project}/accounts:batchCreate`,
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
          console.log(`Password reset successful for ${email}`);
          resolve(JSON.parse(responseBody));
        } else {
          console.error(`Failed to reset password for ${email}:`, res.statusCode, responseBody);
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
    await setPassword('sonia.fatnassi@enis.tn', 'admin123', '7ozFSpO5bohUwUPuieCP5of7BB92');
  } catch(e) { console.error(e); }
  
  try {
    await setPassword('soniafatnassi46@gmail.com', 'admin123', 'vOhtCMPzA3UDFxHzdSuNHLC1aMt1');
  } catch(e) { console.error(e); }
}

run();

const https = require('https');
const fs = require('fs');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const token = config.tokens.access_token;

// L'API correcte pour l'admin : identitytoolkit.googleapis.com Admin API v2
// Endpoint: PATCH https://identitytoolkit.googleapis.com/v2/projects/{project}/tenants/-/inboundSamlConfigs
// En réalité le bon endpoint admin pour changer le mot de passe est:
// POST https://identitytoolkit.googleapis.com/v1/accounts:update (sans clé API, juste le Bearer admin token)
// Avec le champ "password" - mais ça nécessite d'être l'utilisateur lui-même
// Pour l'admin : utiliser https://firebase.googleapis.com/v1alpha/projects/-/androidApps/-/getConfig

// Utiliser l'endpoint: https://www.googleapis.com/identitytoolkit/v3/relyingparty/setAccountInfo
// avec Authorization: Bearer (admin token OAuth2) et localId

function resetPassword(uid, email, newPassword) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      localId: uid,
      email: email,
      password: newPassword
    });

    const options = {
      hostname: 'www.googleapis.com',
      path: '/identitytoolkit/v3/relyingparty/setAccountInfo',
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
          const parsed = JSON.parse(responseBody);
          console.log(`✅ Password updated for ${email}`);
          resolve(parsed);
        } else {
          console.error(`❌ Failed for ${email}:`, res.statusCode, responseBody.substring(0, 300));
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
  console.log('Resetting passwords via Google Identity Toolkit API...\n');
  try {
    await resetPassword('7ozFSpO5bohUwUPuieCP5of7BB92', 'sonia.fatnassi@enis.tn', 'admin123');
  } catch(e) {}
  
  try {
    await resetPassword('vOhtCMPzA3UDFxHzdSuNHLC1aMt1', 'soniafatnassi46@gmail.com', 'admin123');
  } catch(e) {}
}

run();

const https = require('https');
const fs = require('fs');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
let token = config.tokens.access_token;
const refreshToken = config.tokens.refresh_token;
const project = 'smart-trans-dc828';

// Refresher le token si nécessaire
async function refreshAccessToken() {
  return new Promise((resolve, reject) => {
    const body = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}`;
    const options = {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body)
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try {
          const r = JSON.parse(data);
          if (r.access_token) {
            resolve(r.access_token);
          } else {
            reject(new Error('No access_token in refresh response'));
          }
        } catch(e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function deleteDoc(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firestore.googleapis.com',
      path,
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: data ? JSON.parse(data) : null }); }
        catch(e) { resolve({ status: res.statusCode, raw: data }); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  console.log('🔄 Rafraîchissement du token...');
  token = await refreshAccessToken();
  console.log('✅ Token rafraîchi.\n');

  const collections = ['chauffeurs', 'clients', 'administrateurs', 'utilisateurs', 'avis'];
  const idsToDelete = ['1', '2'];

  for (const col of collections) {
    for (const id of idsToDelete) {
      const path = `/v1/projects/${project}/databases/(default)/documents/${col}/${id}`;
      const res = await deleteDoc(path);
      if (res.status === 200) {
        console.log(`✅ Supprimé : ${col}/${id}`);
      } else if (res.status === 404) {
        // Document n'existe pas, on ignore
      } else {
        console.log(`❌ Erreur suppression ${col}/${id} : status ${res.status}`);
      }
    }
  }

  console.log('\n✨ Nettoyage terminé ! Les anciennes données invalides ont été supprimées.');
}

run().catch(console.error);

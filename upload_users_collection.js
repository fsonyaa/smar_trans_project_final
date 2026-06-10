const https = require('https');
const fs = require('fs');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const token = config.tokens.access_token;
const project = 'smart-trans-dc828';

// Documents à insérer
const users = [
  {
    collection: 'users',
    docId: '7ozFSpO5bohUwUPuieCP5of7BB92',
    data: {
      uid: '7ozFSpO5bohUwUPuieCP5of7BB92',
      email: 'sonia.fatnassi@enis.tn',
      nom: 'Sonia Fatnassi (Admin)',
      role: 'admin',
      id: 1,
      photo: ''
    }
  },
  {
    collection: 'users',
    docId: 'vOhtCMPzA3UDFxHzdSuNHLC1aMt1',
    data: {
      uid: 'vOhtCMPzA3UDFxHzdSuNHLC1aMt1',
      email: 'soniafatnassi46@gmail.com',
      nom: 'Sonia',
      role: 'admin',
      id: 2,
      photo: ''
    }
  }
];

function toFirestoreValue(value) {
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') return { integerValue: String(value) };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (value === null) return { nullValue: null };
  return { stringValue: String(value) };
}

function toFirestoreDocument(data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = toFirestoreValue(v);
  }
  return { fields };
}

function uploadDocument(user) {
  return new Promise((resolve, reject) => {
    const doc = toFirestoreDocument(user.data);
    const body = JSON.stringify(doc);
    
    const options = {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${project}/databases/(default)/documents/${user.collection}/${user.docId}`,
      method: 'PATCH',
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
          console.log(`Successfully wrote ${user.collection}/${user.docId}`);
          resolve();
        } else {
          console.error(`Failed to write ${user.collection}/${user.docId}:`, res.statusCode, responseBody);
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
  for (const user of users) {
    try {
      await uploadDocument(user);
    } catch (e) {
      console.error(e);
    }
  }
}

run();

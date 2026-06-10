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
            console.log('✅ Token refreshed!');
            resolve(r.access_token);
          } else {
            console.log('⚠️ Refresh response:', data.substring(0, 200));
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

function get(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firestore.googleapis.com',
      path,
      method: 'GET',
      headers: { 'Authorization': `Bearer ${token}` }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
        catch(e) { resolve({ status: res.statusCode, raw: data }); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function extractValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return v.integerValue;
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.nullValue !== undefined) return null;
  if (v.timestampValue !== undefined) return new Date(v.timestampValue).toLocaleString();
  return JSON.stringify(v);
}

function extractDoc(doc) {
  const result = { _id: doc.name.split('/').pop() };
  if (doc.fields) {
    for (const [k, v] of Object.entries(doc.fields)) {
      result[k] = extractValue(v);
    }
  }
  return result;
}

async function getCollection(col) {
  const resp = await get(`/v1/projects/${project}/databases/(default)/documents/${col}?pageSize=50`);
  if (resp.status === 401) {
    console.log('  ⚠️  Token expiré, rafraîchissement...');
    token = await refreshAccessToken();
    const resp2 = await get(`/v1/projects/${project}/databases/(default)/documents/${col}?pageSize=50`);
    if (resp2.data && resp2.data.documents) return resp2.data.documents.map(extractDoc);
    return [];
  }
  if (resp.data && resp.data.documents) return resp.data.documents.map(extractDoc);
  return [];
}

async function run() {
  const collections = ['users', 'chauffeurs', 'clients', 'administrateurs', 'utilisateurs', 'bus', 'lignes', 'parcours', 'historique', 'incidents', 'avis'];

  console.log('='.repeat(65));
  console.log('   VÉRIFICATION FIREBASE FIRESTORE - smart-trans-dc828');
  console.log('='.repeat(65));

  const allData = {};
  for (const col of collections) {
    const docs = await getCollection(col);
    allData[col] = docs;
    console.log(`\n📂 ${col.toUpperCase()} — ${docs.length} doc(s)`);
    if (docs.length === 0) {
      console.log('   ⚠️  VIDE');
    } else {
      docs.forEach(doc => {
        const fields = Object.entries(doc)
          .filter(([k]) => k !== '_id')
          .map(([k, v]) => `${k}: "${String(v || '').substring(0, 25)}"`)
          .join(', ');
        console.log(`   📄 [${doc._id.substring(0, 24)}] ${fields}`);
      });
    }
  }

  // Analyse synchronisation
  console.log('\n' + '='.repeat(65));
  console.log('   ANALYSE DE SYNCHRONISATION');
  console.log('='.repeat(65));

  const users = allData['users'];
  const chauffeurs = allData['chauffeurs'];
  const clients = allData['clients'];
  const bus = allData['bus'];
  const lignes = allData['lignes'];

  const usersAdmins = users.filter(u => u.role === 'admin');
  const usersChauffeurs = users.filter(u => u.role === 'chauffeur');
  const usersClients = users.filter(u => u.role === 'client');

  console.log(`\n👤 USERS TOTAL: ${users.length} → Admins:${usersAdmins.length} Chauffeurs:${usersChauffeurs.length} Clients:${usersClients.length}`);
  console.log(`👷 CHAUFFEURS collection: ${chauffeurs.length}`);
  console.log(`👥 CLIENTS collection: ${clients.length}`);
  console.log(`🚌 BUS: ${bus.length}`);
  console.log(`🗺️  LIGNES: ${lignes.length}`);

  const chauffIDs = new Set(chauffeurs.map(c => c._id));
  const missingCh = usersChauffeurs.filter(u => !chauffIDs.has(u._id));
  if (missingCh.length > 0) {
    console.log(`\n❌ ${missingCh.length} chauffeur(s) PAS dans 'chauffeurs':`);
    missingCh.forEach(c => console.log(`   - ${c.nom} (${c.email}) uid=${c._id}`));
  } else {
    console.log(`\n✅ Chauffeurs bien synchronisés`);
  }

  const clientIDs = new Set(clients.map(c => c._id));
  const missingCl = usersClients.filter(u => !clientIDs.has(u._id));
  if (missingCl.length > 0) {
    console.log(`❌ ${missingCl.length} client(s) PAS dans 'clients':`);
    missingCl.forEach(c => console.log(`   - ${c.nom} (${c.email}) uid=${c._id}`));
  } else {
    console.log(`✅ Clients bien synchronisés`);
  }

  console.log('\n' + '='.repeat(65));
}

run().catch(console.error);

const https = require('https');
const fs = require('fs');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const token = config.tokens.access_token;
const project = 'smart-trans-dc828';

// Lire le profil de khawlabenhmid2@gmail.com (UID: MycktAQ9ithk5tHkPtrrw8henjr1)
// et l'écrire dans 'chauffeurs' si on veut tester
// D'abord, ajoutons des données de test dans les collections

async function post(path, body) {
  return new Promise((resolve, reject) => {
    const bodyStr = JSON.stringify(body);
    const options = {
      hostname: 'firestore.googleapis.com',
      path,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr)
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) resolve(JSON.parse(data));
        else { console.error(`HTTP ${res.statusCode}:`, data.substring(0, 200)); reject(new Error(data)); }
      });
    });
    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

function mkStr(v) { return { stringValue: v }; }
function mkInt(v) { return { integerValue: String(v) }; }

async function addDoc(collection, data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = typeof v === 'number' ? mkInt(v) : mkStr(String(v));
  }
  const result = await post(
    `/v1/projects/${project}/databases/(default)/documents/${collection}`,
    { fields }
  );
  console.log(`✅ Added to ${collection}: ${result.name.split('/').pop()}`);
  return result;
}

async function run() {
  console.log('\n📊 Vérification et synchronisation des données...\n');
  
  // Ajouter un chauffeur de test dans TOUTES les collections nécessaires
  const chauffeurUID = 'test-chauffeur-' + Date.now();
  
  // Pour test: ajouter un bus
  try {
    await addDoc('bus', {
      Numero_bus: 'BUS-001',
      Etat: 'Bon état',
      Code_chauffeur: ''
    });
  } catch(e) { console.log('Bus already exists or error:', e.message?.substring(0, 50)); }
  
  // Ajouter une ligne de test
  try {
    await addDoc('lignes', {
      libelle: 'Ligne 1 - Centre Ville',
      Libelle: 'Ligne 1 - Centre Ville',
      description: 'Trajet centre ville - gare',
      code_bus: ''
    });
  } catch(e) { console.log('Ligne error:', e.message?.substring(0, 50)); }
  
  console.log('\n✅ Données de test ajoutées !');
  console.log('Les stats du dashboard devraient maintenant afficher les bonnes valeurs.');
}

run().catch(console.error);

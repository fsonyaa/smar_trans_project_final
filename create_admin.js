const https = require('https');
const fs = require('fs');

const configPath = process.env.USERPROFILE + '/.config/configstore/firebase-tools.json';
const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const token = config.tokens.access_token;
const project = 'smart-trans-dc828';
const apiKey = 'AIzaSyBRo-Kb4VsTnyfXGIcn0o-26bzD8JbZreA';

const newEmail = 'khawlabenhmid2@gmail.com';
const newPassword = 'admin123';

// Étape 1 : Créer l'utilisateur Firebase Auth
function createAuthUser(email, password) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      email: email,
      password: password,
      returnSecureToken: true
    });

    const options = {
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signUp?key=${apiKey}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let responseBody = '';
      res.on('data', chunk => responseBody += chunk);
      res.on('end', () => {
        const parsed = JSON.parse(responseBody);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`✅ Auth user created: ${email}`);
          console.log(`   UID: ${parsed.localId}`);
          resolve(parsed);
        } else {
          console.error(`❌ Failed to create auth user: ${parsed.error?.message}`);
          reject(new Error(parsed.error?.message));
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// Étape 2 : Créer le profil Firestore dans la collection 'users'
function createFirestoreUser(uid, email, nom, role) {
  return new Promise((resolve, reject) => {
    const docData = {
      fields: {
        uid: { stringValue: uid },
        email: { stringValue: email },
        nom: { stringValue: nom },
        role: { stringValue: role },
        id: { integerValue: '3' },
        photo: { stringValue: '' }
      }
    };
    const body = JSON.stringify(docData);

    const options = {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${project}/databases/(default)/documents/users/${uid}`,
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
          console.log(`✅ Firestore profile created in 'users' for ${email}`);
          resolve();
        } else {
          console.error(`❌ Firestore failed: ${res.statusCode} ${responseBody.substring(0, 200)}`);
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
  console.log(`\n🚀 Creating admin account: ${newEmail}\n`);

  try {
    const authUser = await createAuthUser(newEmail, newPassword);
    const uid = authUser.localId;

    await createFirestoreUser(uid, newEmail, 'Khawla Admin', 'admin');

    console.log('\n==================================');
    console.log('✅ Compte admin créé avec succès !');
    console.log(`📧 Email    : ${newEmail}`);
    console.log(`🔑 Password : ${newPassword}`);
    console.log(`🆔 UID      : ${uid}`);
    console.log(`👤 Role     : admin`);
    console.log('==================================\n');

  } catch (e) {
    if (e.message && e.message.includes('EMAIL_EXISTS')) {
      console.log(`\n⚠️  Le compte ${newEmail} existe déjà dans Firebase Auth.`);
      console.log(`   Tentative de récupération de l'UID via export...`);
    } else {
      console.error('Erreur:', e.message);
    }
  }
}

run();

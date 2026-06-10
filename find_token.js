const https = require('https');
const { execSync } = require('child_process');
const fs = require('fs');

// Récupérer le token d'accès depuis le fichier de config Firebase CLI
function getFirebaseToken() {
  const configPaths = [
    process.env.APPDATA + '\\firebase\\config.json',
    process.env.HOME + '/.config/firebase/config.json',
  ];
  
  for (const p of configPaths) {
    try {
      if (fs.existsSync(p)) {
        const config = JSON.parse(fs.readFileSync(p, 'utf-8'));
        console.log('Found Firebase config at:', p);
        return config;
      }
    } catch(e) {}
  }
  return null;
}

// Lire le fichier d'authentification Firebase CLI
function getFirebaseCredentials() {
  const paths = [
    process.env.APPDATA + '\\firebase\\credentials.json',
    process.env.HOME + '/.config/firebase/credentials.json',
  ];
  
  for (const p of paths) {
    try {
      if (fs.existsSync(p)) {
        const creds = JSON.parse(fs.readFileSync(p, 'utf-8'));
        console.log('Found credentials at:', p);
        return creds;
      }
    } catch(e) { console.log('Not found:', p); }
  }
  return null;
}

const config = getFirebaseToken();
console.log('Config:', JSON.stringify(config, null, 2).substring(0, 200));

const creds = getFirebaseCredentials();
console.log('Creds keys:', creds ? Object.keys(creds) : 'not found');

// Lister tous les fichiers dans le dossier firebase de AppData
const firebaseDir = process.env.APPDATA + '\\firebase';
try {
  const files = fs.readdirSync(firebaseDir);
  console.log('\nFirebase CLI files:', files);
} catch(e) {
  console.log('Firebase dir not found:', firebaseDir);
}

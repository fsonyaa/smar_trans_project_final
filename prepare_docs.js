const { execSync } = require('child_process');
const https = require('https');

// Utiliser le token Firebase CLI existant
const project = 'smart-trans-dc828';

// Documents à créer dans Firestore via REST API
const users = [
  {
    collection: 'utilisateurs',
    docId: '7ozFSpO5bohUwUPuieCP5of7BB92',
    data: {
      uid: '7ozFSpO5bohUwUPuieCP5of7BB92',
      email: 'sonia.fatnassi@enis.tn',
      nom: 'Sonia Fatnassi (Admin)',
      role: 'admin',
      telephone: '',
      adresse: ''
    }
  },
  {
    collection: 'administrateurs',
    docId: '7ozFSpO5bohUwUPuieCP5of7BB92',
    data: {
      uid: '7ozFSpO5bohUwUPuieCP5of7BB92',
      email: 'sonia.fatnassi@enis.tn',
      nom: 'Sonia Fatnassi (Admin)',
      role: 'admin',
      telephone: '',
      adresse: ''
    }
  },
  {
    collection: 'utilisateurs',
    docId: 'vOhtCMPzA3UDFxHzdSuNHLC1aMt1',
    data: {
      uid: 'vOhtCMPzA3UDFxHzdSuNHLC1aMt1',
      email: 'soniafatnassi46@gmail.com',
      nom: 'Sonia',
      role: 'admin',
      telephone: '',
      adresse: ''
    }
  },
  {
    collection: 'administrateurs',
    docId: 'vOhtCMPzA3UDFxHzdSuNHLC1aMt1',
    data: {
      uid: 'vOhtCMPzA3UDFxHzdSuNHLC1aMt1',
      email: 'soniafatnassi46@gmail.com',
      nom: 'Sonia',
      role: 'admin',
      telephone: '',
      adresse: ''
    }
  }
];

// Convertir en format Firestore JSON
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

// Écrire les fichiers JSON pour utilisation avec curl via firebase
users.forEach((u, i) => {
  const fs = require('fs');
  const doc = toFirestoreDocument(u.data);
  fs.writeFileSync(`doc_${i}.json`, JSON.stringify(doc, null, 2));
  console.log(`Created doc_${i}.json for ${u.collection}/${u.docId}`);
});

console.log('\nDocument files created. Use Firebase REST API to write them.');
console.log('Project:', project);

// Afficher les données pour vérification
users.forEach(u => {
  console.log(`\nCollection: ${u.collection}, Doc: ${u.docId}`);
  console.log('  Role:', u.data.role, '| Email:', u.data.email);
});

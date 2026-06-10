const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function fixDatabase() {
  console.log("=== DIAGNOSTIC DE LA BASE DE DONNÉES ===\n");

  // 1. Lister tous les users Firebase Auth
  const authUsers = await auth.listUsers();
  console.log(`✅ Firebase Auth: ${authUsers.users.length} comptes trouvés:`);
  authUsers.users.forEach(u => {
    console.log(`  - ${u.email} (UID: ${u.uid})`);
  });

  // 2. Lister les collections Firestore
  const collections = await db.listCollections();
  console.log(`\n✅ Collections Firestore:`);
  for (const col of collections) {
    const snap = await col.count().get();
    console.log(`  - ${col.id}: ${snap.data().count} documents`);
  }

  // 3. Créer/Mettre à jour les documents pour les vrais comptes Firebase Auth
  console.log("\n=== CRÉATION DES PROFILS FIRESTORE ===");

  const usersData = [
    {
      uid: "7ozFSpO5bohUwUPuieCP5of7BB92",
      email: "sonia.fatnassi@enis.tn",
      nom: "Sonia Fatnassi",
      role: "admin"
    },
    {
      uid: "vOhtCMPzA3UDFxHzdSuNHLC1aMt1",
      email: "soniafatnassi46@gmail.com",
      nom: "Sonia",
      role: "admin"
    }
  ];

  for (const user of usersData) {
    const docData = {
      uid: user.uid,
      email: user.email,
      nom: user.nom,
      role: user.role,
      telephone: '',
      adresse: '',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Dans 'utilisateurs'
    await db.collection('utilisateurs').doc(user.uid).set(docData, { merge: true });
    console.log(`✅ Profil créé dans 'utilisateurs': ${user.email}`);

    // Dans 'administrateurs' (car role=admin)
    await db.collection('administrateurs').doc(user.uid).set(docData, { merge: true });
    console.log(`✅ Profil créé dans 'administrateurs': ${user.email}`);
  }

  // 4. Vérifier les noms des champs dans utilisateurs (capitalisation)
  console.log("\n=== VÉRIFICATION DES CHAMPS EXISTANTS ===");
  const utilisateurs = await db.collection('utilisateurs').get();
  utilisateurs.docs.forEach(doc => {
    const data = doc.data();
    console.log(`\nDocument: ${doc.id}`);
    Object.keys(data).forEach(key => {
      console.log(`  ${key}: ${JSON.stringify(data[key]).substring(0, 50)}`);
    });
  });

  console.log("\n✅ TERMINÉ !");
  process.exit(0);
}

fixDatabase().catch(e => {
  console.error("ERREUR:", e);
  process.exit(1);
});

# SMART-TRANS Firebase

Cette version utilise:

- Flutter pour le front mobile/web.
- Flask pour le backend API.
- Firebase Firestore comme seule base de donnees.

SQLite, Supabase/PostgREST et l'ancienne URL Render ont ete retires du code actif.

## 1. Configurer Firebase

1. Ouvrir [Firebase Console](https://console.firebase.google.com/).
2. Creer ou choisir un projet.
3. Activer Firestore Database en mode Native.
4. Aller dans Project settings > Service accounts.
5. Generer une cle privee JSON.
6. Placer ce fichier hors git, par exemple:

```powershell
C:\Users\USER\Downloads\smarttrans-projetkhawla-main\serviceAccountKey.json
```

7. Copier `.env.example` vers `.env`, puis mettre le chemin exact:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
GOOGLE_APPLICATION_CREDENTIALS=C:\Users\USER\Downloads\smarttrans-projetkhawla-main\serviceAccountKey.json
PORT=8000
```

## 2. Lancer le backend

```powershell
pip install -r requirements.txt
python app.py
```

Test rapide:

```powershell
curl http://127.0.0.1:8000/test
```

La reponse doit contenir:

```json
{"firebase_connected": true}
```

## 3. Lancer Flutter

Emulateur Android:

```powershell
flutter pub get
flutter run
```

Telephone physique sur le meme Wi-Fi que le PC:

```powershell
ipconfig
flutter run --dart-define=SMARTTRANS_API_URL=http://YOUR_PC_IP:8000
```

Exemple:

```powershell
flutter run --dart-define=SMARTTRANS_API_URL=http://192.168.1.103:8000
```

## 4. Verifier le backend depuis Flutter

Toutes les pages Flutter utilisent maintenant `lib/api_config.dart`.

- Par defaut: `http://10.0.2.2:8000` pour l'emulateur Android.
- Pour un vrai telephone: injecter `SMARTTRANS_API_URL`.
- Render n'est plus utilise.

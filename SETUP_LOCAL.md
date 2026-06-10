# SmartTrans - Configuration Rapide

## Status
✅ Serveur local fonctionnel  
✅ Base de données JSON locale (fallback Firebase)  
✅ Authentification testée  
✅ API accessible via réseau  

## Démarrer le serveur

```bash
bash run_server.sh
```

Ou directement:
```bash
python app.py
```

Serveur accessible à: `http://172.30.106.55:8000`

## Identifiants de test

| Email | Mot de passe | Rôle |
|-------|-------------|------|
| test@local | test123 | client |
| admin@local | admin123 | admin |
| driver@local | driver123 | chauffeur |

## Tester l'API

### Endpoint de test
```bash
curl http://172.30.106.55:8000/test
```

### Login
```bash
curl -X POST http://172.30.106.55:8000/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@local","password":"test123"}'
```

## Lancer sur mobile

### Avec appareil physique (USB)
```bash
flutter run --dart-define=SMARTTRANS_API_URL=http://172.30.106.55:8000
```

### Avec émulateur Android
```bash
flutter run --dart-define=SMARTTRANS_API_URL=http://10.0.2.2:8000
```

### Build APK
```bash
flutter build apk --dart-define=SMARTTRANS_API_URL=http://172.30.106.55:8000 --release
```

## Architecture

```
smarttrans/
├── app.py                    # Serveur Flask Python
├── local_db.py              # Base de données JSON locale
├── local_db.json            # Données (remplace Firebase)
├── .env                     # Configuration
├── lib/
│   ├── main.dart           # Point d'entrée
│   ├── api_config.dart     # Configuration API
│   ├── pages/              # Pages Flutter
│   └── ...
├── run_server.sh           # Script pour démarrer le serveur
└── build_mobile.sh         # Script pour compiler APK
```

## Base de données locale

Au lieu de Firebase, le serveur utilise `local_db.json`:
- Stockage JSON simple
- Pas de dépendance Firebase
- Parfait pour développement local
- Synchronisé automatiquement

## Notes importantes

1. **IP locale**: `172.30.106.55` - À adapter selon votre réseau
2. **Port**: 8000
3. **Protocole**: HTTP (non sécurisé) - OK pour développement
4. **CORS**: Activé pour toutes les origines
5. **Emulateur Android**: Utilise `10.0.2.2` pour accéder à `localhost`
6. **Appareil physique**: Utilise l'adresse IP directe `172.30.106.55`

## Troubleshooting

### Le serveur ne démarre pas
```bash
python -c "import app; print('OK')"
```

### Connexion refusée depuis le mobile
- Vérifier l'IP: `ipconfig` (Windows) ou `ifconfig` (Mac/Linux)
- Vérifier le firewall Windows (port 8000)
- Tester avec `curl`: `curl http://172.30.106.55:8000/test`

### Erreur "Database not available"
- Vérifier `local_db.json` existe et est valide JSON
- Vérifier `local_db.py` est présent
- Vérifier les permissions d'accès au fichier

### Flutter build échoue
```bash
flutter clean
flutter pub get
flutter run
```

## Modification de la base de données

Créer un nouvel utilisateur:
```python
from flask_bcrypt import Bcrypt
import json

bcrypt = Bcrypt()
password_hash = bcrypt.generate_password_hash("password123").decode("utf-8")

user = {
  "ID_utilisateur": 4,
  "Nom": "Nouveau User",
  "Email": "new@local",
  "Mot_de_passe": password_hash,
  "Role": "client",
  "Photo": ""
}

# Ajouter à local_db.json manuellement ou via l'API /register
```

## Prochaines étapes

1. ✅ Serveur local fonctionnel
2. ✅ Base de données en place
3. ✅ API de login testée
4. ⏳ Lancer sur appareil mobile
5. ⏳ Tester tous les endpoints
6. ⏳ Déployer sur Render (optionnel)

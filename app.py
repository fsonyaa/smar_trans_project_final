import json
import os
import random
import string
from datetime import datetime
from functools import wraps

from flask import Flask, jsonify, request
from flask_bcrypt import Bcrypt
from flask_cors import CORS
from flask_mail import Mail, Message

try:
    from dotenv import load_dotenv
except Exception:
    def load_dotenv(*args, **kwargs):
        return False

load_dotenv()

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    HAS_FIREBASE = True
except Exception as exc:
    firebase_admin = None
    credentials = None
    firestore = None
    HAS_FIREBASE = False
    FIREBASE_IMPORT_ERROR = str(exc)
else:
    FIREBASE_IMPORT_ERROR = ""

try:
    from textblob import TextBlob
    from deep_translator import GoogleTranslator
    HAS_NLP = True
except Exception:
    HAS_NLP = False

from local_db import LocalDB

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)
bcrypt = Bcrypt(app)

app.config["MAIL_SERVER"] = "smtp.gmail.com"
app.config["MAIL_PORT"] = 587
app.config["MAIL_USE_TLS"] = True
app.config["MAIL_USERNAME"] = os.environ.get("MAIL_USERNAME", "")
app.config["MAIL_PASSWORD"] = os.environ.get("MAIL_PASSWORD", "")
app.config["MAIL_DEFAULT_SENDER"] = app.config["MAIL_USERNAME"]
mail = Mail(app)

PRIMARY_KEYS = {
    "Utilisateur": "ID_utilisateur",
    "Client": "Code_client",
    "Chauffeur": "Code_chauffeur",
    "Bus": "Code_bus",
    "Ligne": "Code_Ligne",
    "Parcours": "ID_parcours",
    "Avis": "ID_avis",
    "Incident": "ID_incident",
    "Historique": "ID_historique",
    "ResetCode": "Email",
}


def init_firestore():
    if not HAS_FIREBASE:
        print("Firebase not available, using LocalDB")
        return LocalDB("local_db.json"), "Using local JSON database"
    try:
        if not firebase_admin._apps:
            raw_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
            cred_path = (
                os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
                or os.environ.get("FIREBASE_CREDENTIALS")
                or os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH")
            )
            options = {}
            project_id = os.environ.get("FIREBASE_PROJECT_ID")
            if project_id:
                options["projectId"] = project_id

            if raw_json:
                cred = credentials.Certificate(json.loads(raw_json))
                firebase_admin.initialize_app(cred, options)
            elif cred_path:
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred, options)
            else:
                firebase_admin.initialize_app(credentials.ApplicationDefault(), options)
        return firestore.client(), ""
    except Exception as exc:
        print(f"Firebase init failed, using LocalDB: {exc}")
        return LocalDB("local_db.json"), f"Firebase error: {str(exc)}"


db, FIREBASE_ERROR = init_firestore()


def json_ready(value):
    if isinstance(value, dict):
        return {k: json_ready(v) for k, v in value.items()}
    if isinstance(value, list):
        return [json_ready(v) for v in value]
    if isinstance(value, tuple):
        return [json_ready(v) for v in value]
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def respond(payload, status=200):
    return jsonify(json_ready(payload)), status


def require_firebase(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if db is None:
            return respond({
                "error": "Database not available",
                "detail": FIREBASE_ERROR,
            }, 503)
        return fn(*args, **kwargs)
    return wrapper


def to_int(value, default=None):
    if value in (None, ""):
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def same_id(left, right):
    if left is None or right is None:
        return False
    return str(left) == str(right)


def clean(data):
    return {k: v for k, v in data.items() if v is not None}


def next_id(table):
    ref = db.collection("_meta").document(f"{table}_counter")
    snap = ref.get()
    current = int((snap.to_dict() or {}).get("value", 0)) if snap.exists else 0
    value = current + 1
    ref.set({"value": value}, merge=True)
    return value


def sync_counter(table, value):
    value = to_int(value)
    if value is None:
        return
    ref = db.collection("_meta").document(f"{table}_counter")
    snap = ref.get()
    current = int((snap.to_dict() or {}).get("value", 0)) if snap.exists else 0
    if value > current:
        ref.set({"value": value}, merge=True)


def doc_id(table, data_or_id):
    pk = PRIMARY_KEYS[table]
    if isinstance(data_or_id, dict):
        return str(data_or_id.get(pk))
    return str(data_or_id)


def save_doc(table, data, merge=False):
    pk = PRIMARY_KEYS[table]
    if data.get(pk) in (None, ""):
        data[pk] = next_id(table)
    sync_counter(table, data.get(pk))
    db.collection(table).document(doc_id(table, data)).set(clean(data), merge=merge)
    return data[pk]


def update_doc(table, pk_value, data):
    db.collection(table).document(str(pk_value)).set(clean(data), merge=True)


def delete_doc(table, pk_value):
    db.collection(table).document(str(pk_value)).delete()


def all_docs(table, order_by=None, desc=True):
    rows = [snap.to_dict() or {} for snap in db.collection(table).stream()]
    if order_by:
        rows.sort(key=lambda r: (r.get(order_by) is None, r.get(order_by)), reverse=desc)
    return rows


def where_docs(table, filters=None, order_by=None, desc=True):
    rows = all_docs(table, order_by=order_by, desc=desc)
    if not filters:
        return rows
    result = []
    for row in rows:
        if all(same_id(row.get(key), value) for key, value in filters.items()):
            result.append(row)
    return result


def first_doc(table, filters=None):
    rows = where_docs(table, filters)
    return rows[0] if rows else None


def update_where(table, filters, data):
    rows = where_docs(table, filters)
    for row in rows:
        update_doc(table, row[PRIMARY_KEYS[table]], data)
    return len(rows)


def delete_where(table, filters):
    rows = where_docs(table, filters)
    for row in rows:
        delete_doc(table, row[PRIMARY_KEYS[table]])
    return len(rows)


DRIVER_KEYWORDS = ["chauffeur", "conducteur", "impoli", "poli", "conduite", "agressif", "respectueux"]
COMFORT_KEYWORDS = ["confort", "siege", "clim", "propre", "sale", "bruit", "chaud", "froid"]
VEHICLE_KEYWORDS = ["bus", "vehicule", "panne", "moteur", "vieux", "neuf"]
SERVICE_KEYWORDS = ["retard", "heure", "attente", "horaire", "trajet", "ponctuel"]
NEG_WORDS = ["nul", "mauvais", "pire", "sale", "impoli", "retard", "lent", "panne", "danger", "probleme"]
POS_WORDS = ["super", "excellent", "bien", "bon", "rapide", "confortable", "gentil", "merci", "bravo"]


def categorize_comment(comment):
    text = (comment or "").lower()
    groups = [
        ("Chauffeur", DRIVER_KEYWORDS),
        ("Confort", COMFORT_KEYWORDS),
        ("Vehicule", VEHICLE_KEYWORDS),
        ("Service", SERVICE_KEYWORDS),
    ]
    scores = {name: sum(1 for word in words if word in text) for name, words in groups}
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "General"


def analyze_sentiment(comment):
    text = (comment or "").strip()
    lowered = text.lower()
    score = 0.0
    if HAS_NLP and text:
        try:
            translated = GoogleTranslator(source="auto", target="en").translate(text)
            score = float(TextBlob(translated).sentiment.polarity)
        except Exception:
            score = 0.0
    score += 0.25 * sum(1 for word in POS_WORDS if word in lowered)
    score -= 0.35 * sum(1 for word in NEG_WORDS if word in lowered)
    score = max(-1.0, min(1.0, score))
    label = "Positif" if score > 0.15 else "Negatif" if score < -0.15 else "Neutre"
    keywords = [word for word in DRIVER_KEYWORDS + COMFORT_KEYWORDS + VEHICLE_KEYWORDS + SERVICE_KEYWORDS if word in lowered]
    risk = "Oui" if score < -0.55 or "danger" in lowered or "panne" in lowered else "Non"
    return round(score, 3), label, ", ".join(dict.fromkeys(keywords)), categorize_comment(text), risk


def resolve_client_code(value):
    if value is None:
        return None
    client = first_doc("Client", {"Code_client": value}) or first_doc("Client", {"ID_utilisateur": value})
    return client.get("Code_client") if client else value


def resolve_driver_code(user_id):
    chauffeur = first_doc("Chauffeur", {"ID_utilisateur": user_id}) or first_doc("Chauffeur", {"Code_chauffeur": user_id})
    return chauffeur.get("Code_chauffeur") if chauffeur else None


def user_name(user_id, default="Inconnu"):
    user = first_doc("Utilisateur", {"ID_utilisateur": user_id})
    return (user or {}).get("Nom") or default


def client_name(code_client):
    client = first_doc("Client", {"Code_client": code_client}) or first_doc("Client", {"ID_utilisateur": code_client})
    if client:
        return user_name(client.get("ID_utilisateur"), f"Client #{code_client}")
    return f"Client #{code_client}"


def driver_name(code_chauffeur):
    chauffeur = first_doc("Chauffeur", {"Code_chauffeur": code_chauffeur})
    if chauffeur:
        return user_name(chauffeur.get("ID_utilisateur"))
    return "Inconnu"


def line_for_bus(code_bus):
    return first_doc("Ligne", {"Code_bus": code_bus})


def bus_for_driver(code_chauffeur):
    return first_doc("Bus", {"Code_chauffeur": code_chauffeur})


def review_context(id_historique=None, parcours_id=None):
    code_chauffeur = code_ligne = code_bus = None
    hist = first_doc("Historique", {"ID_historique": id_historique}) if id_historique else None
    if hist:
        code_chauffeur = hist.get("Code_chauffeur")
        parcours_id = parcours_id or hist.get("ID_parcours")

    parcours = first_doc("Parcours", {"ID_parcours": parcours_id}) if parcours_id else None
    if parcours:
        code_ligne = parcours.get("Code_Ligne")
        ligne = first_doc("Ligne", {"Code_Ligne": code_ligne})
        if ligne:
            code_bus = ligne.get("Code_bus")
            bus = first_doc("Bus", {"Code_bus": code_bus})
            if bus and not code_chauffeur:
                code_chauffeur = bus.get("Code_chauffeur")

    if not code_bus and code_chauffeur:
        bus = bus_for_driver(code_chauffeur)
        if bus:
            code_bus = bus.get("Code_bus")
            ligne = line_for_bus(code_bus)
            code_ligne = code_ligne or ((ligne or {}).get("Code_Ligne"))
    return code_chauffeur, code_ligne, code_bus, parcours_id


def reviews_for_driver(code_chauffeur):
    reviews = []
    for avis in all_docs("Avis", order_by="Date", desc=True):
        hist = first_doc("Historique", {"ID_historique": avis.get("ID_historique")}) if avis.get("ID_historique") else None
        if hist and same_id(hist.get("Code_chauffeur"), code_chauffeur):
            reviews.append(avis)
            continue
        ctx_driver, _, _, _ = review_context(parcours_id=avis.get("ID_parcours"))
        if same_id(ctx_driver, code_chauffeur):
            reviews.append(avis)
    return reviews


def recalc_driver_performance(code_chauffeur):
    reviews = reviews_for_driver(code_chauffeur)
    if not reviews:
        return 0
    avg_note = sum(float(r.get("Note") or 0) for r in reviews) / len(reviews)
    avg_sentiment = sum(float(r.get("Sentiment_score") or 0) for r in reviews) / len(reviews)
    score = round(avg_note + avg_sentiment * 0.5, 2)
    update_where("Chauffeur", {"Code_chauffeur": code_chauffeur}, {"Performance_score": score})
    return score


def sentiment_distribution(rows):
    counts = {}
    for row in rows:
        label = row.get("Sentiment_label") or "Neutre"
        counts[label] = counts.get(label, 0) + 1
    return counts


def keyword_counts(rows):
    counts = {}
    for row in rows:
        for kw in (row.get("Keywords") or "").split(","):
            kw = kw.strip()
            if kw:
                counts[kw] = counts.get(kw, 0) + 1
    return sorted(counts.items(), key=lambda item: item[1], reverse=True)[:10]


# ─────────────────────────────────────────────
#  ROUTES
# ─────────────────────────────────────────────

@app.route("/test", methods=["GET", "POST"])
def test():
    return respond({
        "message": "SMART-TRANS API fonctionne",
        "firebase_connected": db is not None,
        "firebase_error": FIREBASE_ERROR if db is None else "",
        "nlp_available": HAS_NLP,
    })


# ─────────────────────────────────────────────
#  ROUTE NLP — Appelée par Flutter pour analyser
#  un commentaire AVANT de le sauvegarder
# ─────────────────────────────────────────────
@app.route("/analyze_sentiment", methods=["POST", "OPTIONS"])
def analyze_sentiment_route():
    """Endpoint léger appelé par Flutter pour obtenir le vrai score NLP.
    Ne sauvegarde rien dans la base — retourne juste l'analyse."""
    if request.method == "OPTIONS":
        return respond({"ok": True})
    data = request.get_json() or {}
    commentaire = data.get("commentaire", "")
    note = int(data.get("note", 3))

    score, label, keywords, category, is_risk = analyze_sentiment(commentaire)

    # La note prime sur le sentiment si extrême
    if note >= 4 and label == "Negatif":
        label = "Neutre"
    if note <= 2 and label == "Positif":
        label = "Neutre"

    # Convertir label interne → label affiché en français
    label_fr = {"Positif": "Positif", "Negatif": "Négatif", "Neutre": "Neutre"}.get(label, label)

    return respond({
        "score": score,
        "label": label_fr,
        "keywords": keywords,
        "category": category,
        "is_risk": is_risk,
        "nlp_engine": "textblob" if HAS_NLP else "keywords_only",
    })


@app.route("/register", methods=["POST"])
@require_firebase
def register():
    data = request.get_json() or {}
    nom = (data.get("nom") or "").strip()
    email = (data.get("email") or "").lower().strip()
    password = data.get("password") or ""
    if not nom or not email or not password:
        return respond({"error": "Tous les champs sont obligatoires"}, 400)
    if first_doc("Utilisateur", {"Email": email}):
        return respond({"message": "Email deja utilise"}, 400)
    hashed = bcrypt.generate_password_hash(password).decode("utf-8")
    user_id = next_id("Utilisateur")
    save_doc("Utilisateur", {
        "ID_utilisateur": user_id,
        "Nom": nom,
        "Email": email,
        "Mot_de_passe": hashed,
        "Role": "client",
        "Photo": "",
    })
    save_doc("Client", {"Code_client": user_id, "ID_utilisateur": user_id})
    return respond({"message": "Compte cree avec succes", "id": user_id}, 201)


@app.route("/login", methods=["POST"])
@require_firebase
def login():
    data = request.get_json() or {}
    email = (data.get("email") or "").lower().strip()
    password = data.get("password") or ""
    if not email or not password:
        return respond({"error": "Email et mot de passe obligatoires"}, 400)
    user = first_doc("Utilisateur", {"Email": email})
    if not user:
        return respond({"error": "Utilisateur introuvable"}, 404)
    if not bcrypt.check_password_hash(user.get("Mot_de_passe", ""), password):
        return respond({"error": "Mot de passe incorrect"}, 401)
    return respond({
        "message": "Login successful",
        "id": user.get("ID_utilisateur"),
        "nom": user.get("Nom"),
        "email": user.get("Email"),
        "role": user.get("Role"),
        "photo": user.get("Photo") or "",
    })


@app.route("/forgot-password", methods=["POST"])
@require_firebase
def forgot_password():
    data = request.get_json() or {}
    email = (data.get("email") or "").lower().strip()
    user = first_doc("Utilisateur", {"Email": email})
    if not user:
        return respond({"error": "Aucun compte trouve avec cet email"}, 404)
    code = "".join(random.choices(string.digits, k=6))
    save_doc("ResetCode", {"Email": email, "Code": code, "Created_at": datetime.now().isoformat()}, merge=True)
    if app.config["MAIL_USERNAME"] and app.config["MAIL_PASSWORD"]:
        msg = Message("Code de verification SMART-TRANS", recipients=[email])
        msg.html = f"<h2>SMART-TRANS</h2><p>Bonjour {user.get('Nom')}, votre code est <b>{code}</b>.</p>"
        mail.send(msg)
    return respond({"message": "Code envoye par email"})


@app.route("/verify-reset-code", methods=["POST"])
@require_firebase
def verify_reset_code():
    data = request.get_json() or {}
    item = first_doc("ResetCode", {"Email": (data.get("email") or "").lower().strip()})
    if item and same_id(item.get("Code"), data.get("code")):
        return respond({"message": "Code valide"})
    return respond({"error": "Code invalide ou expire"}, 400)


@app.route("/reset-password", methods=["POST"])
@require_firebase
def reset_password():
    data = request.get_json() or {}
    email = (data.get("email") or "").lower().strip()
    new_password = data.get("new_password") or ""
    if len(new_password) < 6:
        return respond({"error": "Le mot de passe doit contenir au moins 6 caracteres"}, 400)
    item = first_doc("ResetCode", {"Email": email})
    if not item or not same_id(item.get("Code"), data.get("code")):
        return respond({"error": "Action non autorisee"}, 403)
    user = first_doc("Utilisateur", {"Email": email})
    if user:
        update_doc("Utilisateur", user["ID_utilisateur"], {
            "Mot_de_passe": bcrypt.generate_password_hash(new_password).decode("utf-8")
        })
    delete_doc("ResetCode", email)
    return respond({"message": "Mot de passe reinitialise avec succes"})


@app.route("/get_profile/<email>", methods=["GET"])
@require_firebase
def get_profile(email):
    user = first_doc("Utilisateur", {"Email": email.lower().strip()})
    if not user:
        return respond({"error": "Utilisateur introuvable"}, 404)
    return respond({"Nom": user.get("Nom"), "Email": user.get("Email"), "Photo": user.get("Photo")})


@app.route("/update_profile", methods=["POST"])
@require_firebase
def update_profile():
    data = request.get_json() or {}
    user_id = data.get("user_id")
    user = first_doc("Utilisateur", {"ID_utilisateur": user_id})
    if not user:
        return respond({"error": "Utilisateur introuvable"}, 404)
    new_email = data.get("email") or user.get("Email")
    clash = first_doc("Utilisateur", {"Email": new_email})
    if clash and not same_id(clash.get("ID_utilisateur"), user_id):
        return respond({"error": "Cet email est deja utilise"}, 400)
    update = {
        "Nom": data.get("name") or user.get("Nom"),
        "Email": new_email,
        "Photo": data.get("photo") if data.get("photo") is not None else user.get("Photo", ""),
    }
    if data.get("password"):
        update["Mot_de_passe"] = bcrypt.generate_password_hash(data["password"]).decode("utf-8")
    update_doc("Utilisateur", user_id, update)
    return respond({"message": "Profil mis a jour avec succes"})


@app.route("/get_buses", methods=["GET"])
@require_firebase
def get_buses():
    return respond(all_docs("Bus", "Code_bus", True))


@app.route("/add_bus", methods=["POST"])
@require_firebase
def add_bus():
    data = request.get_json() or {}
    new_id = save_doc("Bus", {
        "Numero_bus": data.get("Numero_bus"),
        "Etat": data.get("Etat"),
        "Code_chauffeur": data.get("Code_chauffeur"),
    })
    return respond({"status": "success", "message": "Bus ajoute", "id": new_id}, 201)


@app.route("/update_bus/<int:id>", methods=["PUT"])
@require_firebase
def update_bus(id):
    data = request.get_json() or {}
    update_doc("Bus", id, {
        "Numero_bus": data.get("Numero_bus"),
        "Etat": data.get("Etat"),
        "Code_chauffeur": data.get("Code_chauffeur"),
    })
    return respond({"status": "success", "message": "Bus mis a jour"})


@app.route("/delete_bus/<int:id>", methods=["DELETE"])
@require_firebase
def delete_bus(id):
    delete_where("Incident", {"Code_bus": id})
    update_where("Ligne", {"Code_bus": id}, {"Code_bus": None})
    delete_doc("Bus", id)
    return respond({"status": "success", "message": "Bus supprime"})


@app.route("/get_available_buses", methods=["GET"])
@require_firebase
def get_available_buses():
    return respond([{"Code_bus": b.get("Code_bus"), "Numero_bus": b.get("Numero_bus")} for b in all_docs("Bus")])


@app.route("/get_lignes", methods=["GET"])
@require_firebase
def get_lignes():
    return respond(all_docs("Ligne", "Code_Ligne", True))


@app.route("/get_all_lignes", methods=["GET"])
@require_firebase
def get_all_lignes():
    result = []
    for ligne in all_docs("Ligne", "Code_Ligne", True):
        bus = first_doc("Bus", {"Code_bus": ligne.get("Code_bus")}) if ligne.get("Code_bus") else None
        nom_chauffeur = driver_name(bus.get("Code_chauffeur")) if bus and bus.get("Code_chauffeur") else "Non assigne"
        result.append({
            "code_ligne": ligne.get("Code_Ligne"),
            "libelle": ligne.get("Libelle") or "Sans Nom",
            "description": ligne.get("Description") or "",
            "code_bus": ligne.get("Code_bus"),
            "nom_chauffeur": nom_chauffeur,
        })
    return respond(result)


@app.route("/add_ligne", methods=["POST"])
@require_firebase
def add_ligne():
    data = request.get_json() or {}
    new_id = save_doc("Ligne", {
        "Libelle": data.get("libelle") or data.get("Libelle"),
        "Description": data.get("description") or data.get("Description"),
        "Code_bus": data.get("code_bus") or data.get("Code_bus"),
    })
    return respond({"message": "Ligne ajoutee avec succes", "id": new_id}, 201)


@app.route("/update_ligne/<int:id>", methods=["PUT", "POST"])
@require_firebase
def update_ligne(id):
    data = request.get_json() or {}
    update_doc("Ligne", id, {
        "Libelle": data.get("libelle") or data.get("Libelle"),
        "Description": data.get("description") or data.get("Description"),
        "Code_bus": data.get("code_bus") or data.get("Code_bus"),
    })
    return respond({"message": "Ligne mise a jour"})


@app.route("/delete_ligne/<int:id>", methods=["DELETE"])
@require_firebase
def delete_ligne(id):
    delete_where("Parcours", {"Code_Ligne": id})
    delete_where("Incident", {"Code_Ligne": id})
    delete_doc("Ligne", id)
    return respond({"message": "Ligne supprimee"})


@app.route("/get_chauffeurs", methods=["GET"])
@require_firebase
def get_chauffeurs():
    result = []
    for chauffeur in all_docs("Chauffeur", "Code_chauffeur", True):
        user = first_doc("Utilisateur", {"ID_utilisateur": chauffeur.get("ID_utilisateur")})
        if user:
            result.append({
                "ID_utilisateur": user.get("ID_utilisateur"),
                "Nom": user.get("Nom"),
                "Email": user.get("Email"),
                "Code_chauffeur": chauffeur.get("Code_chauffeur"),
            })
    return respond(result)


@app.route("/add_chauffeur", methods=["POST"])
@require_firebase
def add_chauffeur():
    data = request.get_json() or {}
    nom, email, password = data.get("Nom"), (data.get("Email") or "").lower().strip(), data.get("Password")
    if not nom or not email or not password:
        return respond({"error": "Nom, Email et Password sont obligatoires"}, 400)
    if first_doc("Utilisateur", {"Email": email}):
        return respond({"error": "Email deja utilise"}, 400)
    user_id = next_id("Utilisateur")
    hashed = bcrypt.generate_password_hash(password).decode("utf-8")
    save_doc("Utilisateur", {"ID_utilisateur": user_id, "Nom": nom, "Email": email, "Mot_de_passe": hashed, "Role": "chauffeur", "Photo": ""})
    save_doc("Chauffeur", {"Code_chauffeur": user_id, "ID_utilisateur": user_id, "Performance_score": 0})
    return respond({"message": "Chauffeur ajoute avec succes", "id": user_id}, 201)


@app.route("/update_chauffeur/<int:id>", methods=["PUT"])
@require_firebase
def update_chauffeur(id):
    data = request.get_json() or {}
    user = first_doc("Utilisateur", {"ID_utilisateur": id})
    if not user:
        return respond({"error": "Chauffeur introuvable"}, 404)
    update = {"Nom": data.get("Nom"), "Email": (data.get("Email") or "").lower().strip()}
    if data.get("Password"):
        update["Mot_de_passe"] = bcrypt.generate_password_hash(data["Password"]).decode("utf-8")
    update_doc("Utilisateur", id, update)
    return respond({"message": "Chauffeur mis a jour"})


@app.route("/delete_chauffeur/<int:id>", methods=["DELETE"])
@require_firebase
def delete_chauffeur(id):
    chauffeur = first_doc("Chauffeur", {"ID_utilisateur": id})
    if chauffeur:
        update_where("Bus", {"Code_chauffeur": chauffeur.get("Code_chauffeur")}, {"Code_chauffeur": None})
        delete_doc("Chauffeur", chauffeur.get("Code_chauffeur"))
    delete_doc("Utilisateur", id)
    return respond({"message": "Chauffeur supprime avec succes"})


@app.route("/assign_work", methods=["POST"])
@require_firebase
def assign_work():
    data = request.get_json() or {}
    update_doc("Bus", data.get("code_bus"), {"Code_chauffeur": data.get("code_chauffeur")})
    update_doc("Ligne", data.get("code_ligne"), {"Code_bus": data.get("code_bus")})
    return respond({"message": "Affectation reussie"})


@app.route("/get_all_parcours", methods=["GET"])
@require_firebase
def get_all_parcours():
    result = []
    for parcours in all_docs("Parcours", "ID_parcours", True):
        ligne = first_doc("Ligne", {"Code_Ligne": parcours.get("Code_Ligne")})
        item = dict(parcours)
        item["Nom_Ligne"] = (ligne or {}).get("Libelle", "Sans nom")
        result.append(item)
    return respond(result)


@app.route("/get_parcours/<int:code_ligne>", methods=["GET"])
@require_firebase
def get_parcours_by_ligne(code_ligne):
    return respond(where_docs("Parcours", {"Code_Ligne": code_ligne}))


@app.route("/add_parcours", methods=["POST"])
@require_firebase
def add_parcours():
    data = request.get_json() or {}
    new_id = save_doc("Parcours", {
        "Depart": data.get("Depart"),
        "Arrivee": data.get("Arrivee"),
        "Heure_depart": data.get("Heure_depart"),
        "Heure_arrivee": data.get("Heure_arrivee", "--:--"),
        "Code_Ligne": data.get("Code_Ligne"),
    })
    return respond({"message": "Parcours ajoute", "id": new_id}, 201)


@app.route("/update_parcours/<int:id>", methods=["PUT", "POST", "OPTIONS"])
@require_firebase
def update_parcours(id):
    if request.method == "OPTIONS":
        return respond({"ok": True})
    data = request.get_json() or {}
    update_doc("Parcours", id, {
        "Depart": data.get("Depart"),
        "Arrivee": data.get("Arrivee"),
        "Heure_depart": data.get("Heure_depart"),
        "Heure_arrivee": data.get("Heure_arrivee"),
        "Code_Ligne": data.get("Code_Ligne"),
    })
    return respond({"status": "success", "message": "Mise a jour reussie"})


@app.route("/delete_parcours/<int:id>", methods=["DELETE", "OPTIONS"])
@require_firebase
def delete_parcours(id):
    if request.method == "OPTIONS":
        return respond({"ok": True})
    delete_doc("Parcours", id)
    return respond({"status": "success"})


@app.route("/add_avis", methods=["POST", "OPTIONS"])
@require_firebase
def add_avis():
    if request.method == "OPTIONS":
        return respond({"ok": True})
    data = request.get_json() or {}
    comment = data.get("commentaire", "")
    score, label, keywords, category, is_risk = analyze_sentiment(comment)
    client_id = resolve_client_code(data.get("client_id") or data.get("code_client"))
    code_chauffeur, code_ligne, code_bus, parcours_id = review_context(data.get("id_historique"), data.get("parcours_id"))
    date_avis = data.get("date") or datetime.now().strftime("%Y-%m-%d")
    new_id = save_doc("Avis", {
        "Code_client": client_id,
        "ID_historique": data.get("id_historique"),
        "ID_parcours": parcours_id,
        "Note": data.get("note", 5),
        "Commentaire": comment,
        "Sentiment_score": score,
        "Sentiment_label": label,
        "Keywords": keywords,
        "Category": category,
        "Date": date_avis,
    })
    if code_chauffeur:
        recalc_driver_performance(code_chauffeur)
    if is_risk == "Oui":
        save_doc("Incident", {
            "Description": f"[IA ALERT] {comment}",
            "Date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "Code_chauffeur": code_chauffeur,
            "Code_Ligne": code_ligne,
            "Code_bus": code_bus,
            "Statut": "Signale",
        })
    return respond({"status": "success", "id": new_id, "ai_analysis": {"score": score, "label": label, "keywords": keywords}}, 201)


@app.route("/get_avis", methods=["GET"])
@require_firebase
def get_avis():
    result = []
    for avis in all_docs("Avis", "Date", True):
        item = dict(avis)
        item["Nom_Client"] = client_name(avis.get("Code_client"))
        result.append(item)
    return respond(result)


@app.route("/get_avis_by_client/<int:client_id>", methods=["GET"])
@require_firebase
def get_avis_by_client(client_id):
    code_client = resolve_client_code(client_id)
    result = []
    for avis in where_docs("Avis", {"Code_client": code_client}, "Date", True):
        hist = first_doc("Historique", {"ID_historique": avis.get("ID_historique")}) if avis.get("ID_historique") else {}
        item = dict(avis)
        item["Depart"] = (hist or {}).get("Depart")
        item["Arrivee"] = (hist or {}).get("Arrivee")
        result.append(item)
    return respond(result)


@app.route("/get_my_reviews/<int:client_id>", methods=["GET"])
@require_firebase
def get_my_reviews(client_id):
    return get_avis_by_client(client_id)


@app.route("/update_avis/<int:id>", methods=["PUT"])
@require_firebase
def update_avis(id):
    data = request.get_json() or {}
    update = {"Commentaire": data.get("commentaire"), "Note": data.get("note")}
    if data.get("commentaire"):
        score, label, keywords, category, _ = analyze_sentiment(data.get("commentaire"))
        update.update({"Sentiment_score": score, "Sentiment_label": label, "Keywords": keywords, "Category": category})
    update_doc("Avis", id, update)
    return respond({"message": "Avis mis a jour"})


@app.route("/delete_avis/<int:id>", methods=["DELETE"])
@require_firebase
def delete_avis(id):
    delete_doc("Avis", id)
    return respond({"message": "Avis supprime"})


@app.route("/recategorize_avis", methods=["POST"])
@require_firebase
def recategorize_avis():
    updated = 0
    for avis in all_docs("Avis"):
        update_doc("Avis", avis["ID_avis"], {"Category": categorize_comment(avis.get("Commentaire"))})
        updated += 1
    return respond({"status": "ok", "updated": updated})


@app.route("/get_incidents", methods=["GET"])
@require_firebase
def get_incidents():
    result = []
    for incident in all_docs("Incident", "Date", True):
        bus = first_doc("Bus", {"Code_bus": incident.get("Code_bus")})
        item = dict(incident)
        item["Numero_bus"] = (bus or {}).get("Numero_bus", "N/A")
        item["NomChauffeur"] = driver_name(incident.get("Code_chauffeur"))
        result.append(item)
    return respond(result)


@app.route("/get_all_incidents", methods=["GET"])
@require_firebase
def get_all_incidents():
    result = []
    for incident in all_docs("Incident", "Date", True):
        ligne = first_doc("Ligne", {"Code_Ligne": incident.get("Code_Ligne")})
        bus = first_doc("Bus", {"Code_bus": incident.get("Code_bus") or (ligne or {}).get("Code_bus")})
        item = dict(incident)
        item["Nom_Ligne"] = (ligne or {}).get("Libelle", "N/A")
        item["Numero_bus"] = (bus or {}).get("Numero_bus", "N/A")
        result.append(item)
    return respond(result)


@app.route("/add_incident", methods=["POST"])
@require_firebase
def add_incident():
    data = request.get_json() or {}
    code_chauffeur = data.get("Code_chauffeur") or data.get("code_chauffeur")
    code_bus = data.get("Code_bus") or data.get("code_bus")
    if not code_bus and code_chauffeur:
        bus = bus_for_driver(code_chauffeur)
        code_bus = (bus or {}).get("Code_bus")
    new_id = save_doc("Incident", {
        "Description": data.get("description", ""),
        "Date": data.get("Date") or datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "Code_chauffeur": code_chauffeur,
        "Code_Ligne": data.get("Code_Ligne") or data.get("code_ligne"),
        "Code_bus": code_bus,
        "Statut": data.get("Statut", "Signale"),
    })
    return respond({"message": "Incident ajoute", "id": new_id}, 201)


@app.route("/declare_incident", methods=["POST", "OPTIONS"])
@require_firebase
def declare_incident():
    if request.method == "OPTIONS":
        return respond({"status": "ok"})
    data = request.get_json() or {}
    code_chauffeur = resolve_driver_code(data.get("driver_id"))
    if not code_chauffeur:
        return respond({"error": "Chauffeur introuvable"}, 404)
    bus = bus_for_driver(code_chauffeur)
    ligne = line_for_bus((bus or {}).get("Code_bus"))
    save_doc("Incident", {
        "Description": data.get("description", ""),
        "Date": data.get("timestamp") or datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "Code_chauffeur": code_chauffeur,
        "Code_Ligne": (ligne or {}).get("Code_Ligne"),
        "Code_bus": (bus or {}).get("Code_bus"),
        "Statut": "Signale",
    })
    return respond({"message": "Incident signale avec succes"}, 201)


@app.route("/delete_incident/<int:id>", methods=["DELETE"])
@require_firebase
def delete_incident(id):
    delete_doc("Incident", id)
    return respond({"status": "success", "message": "Incident supprime"})


@app.route("/update_incident_status/<int:id>", methods=["POST"])
@require_firebase
def update_incident_status(id):
    data = request.get_json() or {}
    update_doc("Incident", id, {"Statut": data.get("Statut"), "Performance_IA": data.get("Critique")})
    return respond({"message": "Statut mis a jour"})


@app.route("/log_historique", methods=["POST"])
@require_firebase
def log_historique():
    data = request.get_json() or {}
    code_chauffeur = resolve_driver_code(data.get("driver_id"))
    if not code_chauffeur:
        return respond({"error": "Chauffeur introuvable"}, 404)
    action = data.get("action")
    parcours_id = data.get("parcours_id")
    now = data.get("timestamp") or datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if action in ("Debut", "Début"):
        new_id = save_doc("Historique", {
            "Date": now,
            "Heure_fin": None,
            "Statut": "En cours",
            "Depart": data.get("depart"),
            "Arrivee": data.get("arrivee"),
            "Performance_IA": None,
            "ID_parcours": parcours_id,
            "Code_chauffeur": code_chauffeur,
        })
        return respond({"message": "Voyage demarre", "id": new_id}, 201)
    if action == "Fin":
        updated = 0
        for hist in all_docs("Historique", "ID_historique", True):
            if same_id(hist.get("Code_chauffeur"), code_chauffeur) and same_id(hist.get("ID_parcours"), parcours_id) and hist.get("Statut") == "En cours":
                update_doc("Historique", hist["ID_historique"], {"Heure_fin": now, "Statut": "Termine", "Performance_IA": 100.0})
                updated += 1
        return respond({"message": "Voyage termine", "updated": updated}, 201)
    return respond({"error": "Action invalide"}, 400)


@app.route("/get_all_historique", methods=["GET"])
@require_firebase
def get_all_historique():
    result = []
    for hist in all_docs("Historique", "Date", True):
        parcours = first_doc("Parcours", {"ID_parcours": hist.get("ID_parcours")})
        ligne = first_doc("Ligne", {"Code_Ligne": (parcours or {}).get("Code_Ligne")}) if parcours else None
        item = dict(hist)
        item["Nom_Chauffeur"] = driver_name(hist.get("Code_chauffeur"))
        item["Nom_Ligne"] = (ligne or {}).get("Libelle", "N/A")
        result.append(item)
    return respond(result)


@app.route("/get_counts", methods=["GET"])
@require_firebase
def get_counts():
    return respond({
        "lignes": len(all_docs("Ligne")),
        "chauffeurs": len(all_docs("Chauffeur")),
        "bus": len(all_docs("Bus")),
        "incidents": len(all_docs("Incident")),
    })


@app.route("/get_performance_v2", methods=["GET"])
@require_firebase
def get_performance_v2():
    result = []
    for chauffeur in all_docs("Chauffeur"):
        rows = reviews_for_driver(chauffeur.get("Code_chauffeur"))
        if rows:
            avg = sum(float(r.get("Note") or 0) for r in rows) / len(rows)
            result.append({"Nom_Chauffeur": driver_name(chauffeur.get("Code_chauffeur")), "Total_Avis": len(rows), "Average_Note": round(avg, 2)})
    return respond(result)


@app.route("/get_driver_stats/<int:user_id>", methods=["GET"])
@require_firebase
def get_driver_stats(user_id):
    code_chauffeur = resolve_driver_code(user_id)
    if not code_chauffeur:
        return respond({"error": "Chauffeur introuvable"}, 404)
    reviews = reviews_for_driver(code_chauffeur)
    category_counts = {}
    for row in reviews:
        cat = row.get("Category") or "General"
        category_counts[cat] = category_counts.get(cat, 0) + 1
    incidents = where_docs("Incident", {"Code_chauffeur": code_chauffeur})
    chauffeur = first_doc("Chauffeur", {"Code_chauffeur": code_chauffeur}) or {}
    return respond({
        "performance_score": round(float(chauffeur.get("Performance_score") or recalc_driver_performance(code_chauffeur) or 0), 2),
        "incident_count": len(incidents),
        "recent_reviews": reviews[:5],
        "category_distribution": category_counts,
    })


@app.route("/get_driver_reviews/<int:user_id>", methods=["GET"])
@require_firebase
def get_driver_reviews(user_id):
    code_chauffeur = resolve_driver_code(user_id)
    if not code_chauffeur:
        return respond([])
    return respond([{
        "commentaire": row.get("Commentaire"),
        "note": row.get("Note"),
        "sentiment": row.get("Sentiment_label"),
        "category": row.get("Category"),
        "date": row.get("Date"),
    } for row in reviews_for_driver(code_chauffeur)])


@app.route("/get_nlp_report", methods=["GET"])
@require_firebase
def get_nlp_report():
    avis = all_docs("Avis", "Date", True)
    avg_score = sum(float(a.get("Sentiment_score") or 0) for a in avis) / len(avis) if avis else 0
    top_drivers = []
    for chauffeur in all_docs("Chauffeur"):
        rows = reviews_for_driver(chauffeur.get("Code_chauffeur"))
        if rows:
            avg = sum(float(r.get("Sentiment_score") or 0) for r in rows) / len(rows)
            top_drivers.append({"Nom": driver_name(chauffeur.get("Code_chauffeur")), "avg_sentiment": round(avg, 2), "nb_avis": len(rows)})
    top_drivers.sort(key=lambda r: r["avg_sentiment"], reverse=True)
    parcours_stats = []
    for parcours in all_docs("Parcours"):
        rows = [a for a in avis if same_id(a.get("ID_parcours"), parcours.get("ID_parcours"))]
        if rows:
            avg = sum(float(r.get("Sentiment_score") or 0) for r in rows) / len(rows)
            parcours_stats.append({"ID_parcours": parcours.get("ID_parcours"), "Depart": parcours.get("Depart"), "Arrivee": parcours.get("Arrivee"), "avg_sentiment": round(avg, 2), "nb_avis": len(rows)})
    return respond({
        "total_avis": len(avis),
        "sentiment_distribution": sentiment_distribution(avis),
        "average_sentiment_score": round(avg_score, 2),
        "top_keywords": keyword_counts(avis),
        "top_drivers": top_drivers[:3],
        "parcours_stats": parcours_stats,
        "safety_alerts_count": len([i for i in all_docs("Incident") if str(i.get("Description", "")).startswith("[IA ALERT]")]),
    })


@app.route("/get_driver_nlp_report", methods=["GET"])
@require_firebase
def get_driver_nlp_report():
    avis = [a for a in all_docs("Avis", "Date", True) if a.get("Category") == "Chauffeur"]
    avg_score = sum(float(a.get("Sentiment_score") or 0) for a in avis) / len(avis) if avis else 0
    avg_note = sum(float(a.get("Note") or 0) for a in avis) / len(avis) if avis else 0
    return respond({
        "total_avis_chauffeur": len(avis),
        "satisfaction_chauffeur": round(((avg_score + 1) / 2) * 100, 1),
        "avg_note": round(avg_note, 2),
        "avg_sentiment_score": round(avg_score, 2),
        "sentiment_distribution": sentiment_distribution(avis),
        "top_keywords": keyword_counts(avis),
        "top_drivers": [],
        "avis_list": [{**a, "Nom_Client": client_name(a.get("Code_client"))} for a in avis],
    })


@app.route("/get_client_trips", methods=["GET"])
@require_firebase
def get_client_trips():
    result = []
    for ligne in all_docs("Ligne", "Code_Ligne", True):
        rides = []
        for hist in all_docs("Historique", "Date", True):
            parcours = first_doc("Parcours", {"ID_parcours": hist.get("ID_parcours")})
            if parcours and same_id(parcours.get("Code_Ligne"), ligne.get("Code_Ligne")):
                rides.append({
                    "ID_historique": hist.get("ID_historique"),
                    "Date": hist.get("Date"),
                    "Depart": hist.get("Depart"),
                    "Arrivee": hist.get("Arrivee"),
                    "Nom_Chauffeur": driver_name(hist.get("Code_chauffeur")),
                })
        result.append({"code_ligne": ligne.get("Code_Ligne"), "libelle": ligne.get("Libelle") or "Ligne", "description": ligne.get("Description") or "", "rides": rides})
    return respond(result)


@app.route("/get_my_assignment/<int:user_id>", methods=["GET"])
@require_firebase
def get_my_assignment(user_id):
    code_chauffeur = resolve_driver_code(user_id)
    if not code_chauffeur:
        return respond([])
    today = datetime.now().strftime("%Y-%m-%d")
    result = []
    for bus in where_docs("Bus", {"Code_chauffeur": code_chauffeur}):
        for ligne in where_docs("Ligne", {"Code_bus": bus.get("Code_bus")}):
            for parcours in where_docs("Parcours", {"Code_Ligne": ligne.get("Code_Ligne")}):
                histories = [
                    h for h in all_docs("Historique", "ID_historique", True)
                    if same_id(h.get("ID_parcours"), parcours.get("ID_parcours"))
                    and same_id(h.get("Code_chauffeur"), code_chauffeur)
                    and str(h.get("Date", "")).startswith(today)
                ]
                status = histories[0].get("Statut") if histories else "Pas demarre"
                result.append({
                    "ID_parcours": parcours.get("ID_parcours"),
                    "Depart": parcours.get("Depart") or "---",
                    "Arrivee": parcours.get("Arrivee") or "---",
                    "Heure_depart": parcours.get("Heure_depart") or "--:--",
                    "Heure_arrivee": parcours.get("Heure_arrivee") or "--:--",
                    "Libelle": ligne.get("Libelle"),
                    "Statut": status,
                })
    result.sort(key=lambda row: (row.get("Libelle") or "", row.get("Heure_depart") or ""))
    return respond(result)


@app.route("/get_parcours_reviews/<int:parcours_id>", methods=["GET"])
@require_firebase
def get_parcours_reviews(parcours_id):
    result = []
    for avis in all_docs("Avis", "Date", True):
        hist = first_doc("Historique", {"ID_historique": avis.get("ID_historique")}) if avis.get("ID_historique") else None
        if same_id(avis.get("ID_parcours"), parcours_id) or (hist and same_id(hist.get("ID_parcours"), parcours_id)):
            item = dict(avis)
            item["Nom_Client"] = client_name(avis.get("Code_client"))
            result.append(item)
    return respond(result)


@app.route("/finish_parcours/<int:id_p>", methods=["PUT"])
@require_firebase
def finish_parcours(id_p):
    heure_arrivee = datetime.now().strftime("%H:%M")
    update_doc("Parcours", id_p, {"Heure_arrivee": heure_arrivee})
    return respond({"status": "success", "heure_arrivee": heure_arrivee})


@app.route("/check_sync_status", methods=["GET"])
@require_firebase
def check_sync_status():
    tables = ["Ligne", "Parcours", "Bus", "Chauffeur", "Utilisateur", "Avis", "Incident", "Historique"]
    return respond({
        "firebase_connected": True,
        "database": "Firestore",
        "tables": {table: {"firestore": len(all_docs(table)), "ok": True} for table in tables},
    })


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    app.run(host="0.0.0.0", port=port, debug=False)
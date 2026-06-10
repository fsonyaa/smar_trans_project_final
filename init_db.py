#!/usr/bin/env python3
"""Initialize database with test users for mobile testing"""
import json
import os
from flask_bcrypt import Bcrypt

bcrypt = Bcrypt()

# Test users
test_users = [
    {"email": "test@local", "password": "test123", "nom": "Test User", "role": "client"},
    {"email": "admin@local", "password": "admin123", "nom": "Admin User", "role": "admin"},
    {"email": "driver@local", "password": "driver123", "nom": "Driver User", "role": "chauffeur"},
]

def init_db():
    data = {
        "_meta": {
            "Utilisateur_counter": {"value": len(test_users)},
            "Client_counter": {"value": 1},
            "Chauffeur_counter": {"value": 1},
        },
        "Utilisateur": [],
        "Client": [],
        "Chauffeur": [],
    }

    for idx, user in enumerate(test_users, 1):
        hashed = bcrypt.generate_password_hash(user["password"]).decode("utf-8")
        data["Utilisateur"].append({
            "ID_utilisateur": idx,
            "Nom": user["nom"],
            "Email": user["email"],
            "Mot_de_passe": hashed,
            "Role": user["role"],
            "Photo": "",
        })

        if user["role"] == "client":
            data["Client"].append({
                "Code_client": idx,
                "ID_utilisateur": idx,
            })
        elif user["role"] == "chauffeur":
            data["Chauffeur"].append({
                "Code_chauffeur": idx,
                "ID_utilisateur": idx,
            })

    with open("local_db.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print("[OK] Database initialized")
    print("\nTest credentials:")
    for user in test_users:
        print(f"  {user['email']} / {user['password']} ({user['role']})")

if __name__ == "__main__":
    init_db()

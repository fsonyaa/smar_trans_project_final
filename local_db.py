import json
import os
from threading import Lock

class LocalDB:
    def __init__(self, filepath='local_db.json'):
        self.filepath = filepath
        self.lock = Lock()
        self._load()

    def _load(self):
        try:
            if os.path.exists(self.filepath):
                with open(self.filepath, 'r', encoding='utf-8') as f:
                    self.data = json.load(f)
            else:
                self.data = {}
        except:
            self.data = {}

    def _save(self):
        try:
            with open(self.filepath, 'w', encoding='utf-8') as f:
                json.dump(self.data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving local_db: {e}")

    def collection(self, name):
        return CollectionRef(self, name)

    def get_collection(self, name):
        if name not in self.data:
            self.data[name] = {}
        return self.data[name]

class CollectionRef:
    def __init__(self, db, name):
        self.db = db
        self.name = name

    def document(self, doc_id):
        return DocumentRef(self.db, self.name, str(doc_id))

    def stream(self):
        with self.db.lock:
            self.db._load()
            collection_data = self.db.get_collection(self.name)
            for doc_id, data in collection_data.items():
                yield DocumentSnapshot(doc_id, data)

class DocumentRef:
    def __init__(self, db, collection, doc_id):
        self.db = db
        self.collection = collection
        self.doc_id = str(doc_id)

    def set(self, data, merge=False):
        with self.db.lock:
            self.db._load()
            coll = self.db.get_collection(self.collection)
            if merge and self.doc_id in coll:
                coll[self.doc_id].update(data)
            else:
                coll[self.doc_id] = data
            self.db._save()

    def get(self):
        with self.db.lock:
            self.db._load()
            coll = self.db.get_collection(self.collection)
            data = coll.get(self.doc_id)
            return DocumentSnapshot(self.doc_id, data) if data is not None else DocumentSnapshot(self.doc_id, None)

    def delete(self):
        with self.db.lock:
            self.db._load()
            coll = self.db.get_collection(self.collection)
            if self.doc_id in coll:
                del coll[self.doc_id]
            self.db._save()

class DocumentSnapshot:
    def __init__(self, doc_id, data):
        self.doc_id = doc_id
        self._data = data

    def to_dict(self):
        return self._data

    @property
    def exists(self):
        return self._data is not None

    def get(self, key):
        if self._data is None:
            return None
        return self._data.get(key)

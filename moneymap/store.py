import os
from datetime import datetime
from tinydb import TinyDB, Query

DB_PATH = os.environ.get("MONEYMAP_DB", "db.json")

_db = None


def get_db() -> TinyDB:
    global _db
    if _db is None:
        _db = TinyDB(DB_PATH)
    return _db


def reset_db():
    """Drop everything. Mostly for tests."""
    global _db
    db = get_db()
    db.truncate()
    _db = None


def insert_transaction(data: dict) -> dict:
    db = get_db()
    table = db.table("transactions")
    data["created_at"] = datetime.utcnow().isoformat()
    doc_id = table.insert(data)
    data["id"] = doc_id
    return data


def get_transactions(
    txn_type: str | None = None,
    category: str | None = None,
    year: int | None = None,
    month: int | None = None,
) -> list[dict]:
    db = get_db()
    table = db.table("transactions")

    results = table.all()

    if txn_type:
        results = [r for r in results if r.get("txn_type") == txn_type]
    if category:
        results = [r for r in results if r.get("category") == category]
    if year:
        results = [r for r in results if r.get("date", "").startswith(str(year))]
    if month and year:
        prefix = f"{year}-{month:02d}"
        results = [r for r in results if r.get("date", "").startswith(prefix)]

    for r in results:
        if "id" not in r:
            r["id"] = r.doc_id if hasattr(r, "doc_id") else 0
    return results


def get_transaction_by_id(txn_id: int) -> dict | None:
    db = get_db()
    table = db.table("transactions")
    doc = table.get(doc_id=txn_id)
    if doc:
        doc["id"] = doc.doc_id
    return doc


def delete_transaction(txn_id: int) -> bool:
    db = get_db()
    table = db.table("transactions")
    try:
        table.remove(doc_ids=[txn_id])
        return True
    except KeyError:
        return False

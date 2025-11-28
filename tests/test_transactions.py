def test_create_income(client):
    resp = client.post("/api/transactions/", json={
        "amount": 3000,
        "txn_type": "income",
        "category": "freelance",
        "description": "Web project",
        "date": "2025-09-01",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["amount"] == 3000
    assert data["txn_type"] == "income"
    assert data["category"] == "freelance"


def test_create_expense(client):
    resp = client.post("/api/transactions/", json={
        "amount": 49.99,
        "txn_type": "expense",
        "category": "utilities",
        "tags": ["electric"],
        "date": "2025-09-05",
    })
    assert resp.status_code == 201
    assert resp.json()["tags"] == ["electric"]


def test_invalid_amount(client):
    resp = client.post("/api/transactions/", json={
        "amount": -10,
        "txn_type": "expense",
        "category": "food",
    })
    assert resp.status_code == 422


def test_list_transactions(client, sample_income, sample_expense):
    resp = client.get("/api/transactions/")
    assert resp.status_code == 200
    data = resp.json()
    assert data["count"] == 2


def test_filter_by_type(client, sample_income, sample_expense):
    resp = client.get("/api/transactions/?txn_type=income")
    data = resp.json()
    assert data["count"] == 1
    assert data["transactions"][0]["txn_type"] == "income"


def test_filter_by_tag(client, sample_income, sample_expense):
    resp = client.get("/api/transactions/?tag=food")
    data = resp.json()
    assert data["count"] == 1
    assert data["transactions"][0]["category"] == "groceries"


def test_filter_by_category(client, sample_income, sample_expense):
    resp = client.get("/api/transactions/?category=salary")
    data = resp.json()
    assert data["count"] == 1


def test_get_single_transaction(client, sample_income):
    txn_id = sample_income["id"]
    resp = client.get(f"/api/transactions/{txn_id}")
    assert resp.status_code == 200
    assert resp.json()["category"] == "salary"


def test_get_missing_transaction(client):
    resp = client.get("/api/transactions/999")
    assert resp.status_code == 404


def test_delete_transaction(client, sample_expense):
    txn_id = sample_expense["id"]
    resp = client.delete(f"/api/transactions/{txn_id}")
    assert resp.status_code == 204

    resp = client.get(f"/api/transactions/{txn_id}")
    assert resp.status_code == 404


def test_delete_missing(client):
    resp = client.delete("/api/transactions/999")
    assert resp.status_code == 404

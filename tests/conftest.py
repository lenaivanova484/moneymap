import os
import pytest

os.environ["MONEYMAP_DB"] = "/tmp/moneymap_test.json"

from fastapi.testclient import TestClient
from moneymap.main import app
from moneymap import store


@pytest.fixture(autouse=True)
def clean_db():
    store.reset_db()
    yield
    store.reset_db()
    if os.path.exists("/tmp/moneymap_test.json"):
        os.remove("/tmp/moneymap_test.json")


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def sample_income(client):
    resp = client.post("/api/transactions/", json={
        "amount": 5000,
        "txn_type": "income",
        "category": "salary",
        "description": "Monthly paycheck",
        "date": "2025-10-15",
    })
    return resp.json()


@pytest.fixture
def sample_expense(client):
    resp = client.post("/api/transactions/", json={
        "amount": 120.50,
        "txn_type": "expense",
        "category": "groceries",
        "description": "Weekly groceries",
        "date": "2025-10-18",
    })
    return resp.json()

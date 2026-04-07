#!/bin/bash
set -e

AUTHOR_NAME="${1:?Usage: bash setup_history.sh <name> <email>}"
AUTHOR_EMAIL="${2:?Usage: bash setup_history.sh <name> <email>}"

commit_at() {
    local date="$1"
    local msg="$2"
    shift 2
    git add "$@"
    GIT_AUTHOR_NAME="$AUTHOR_NAME" \
    GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL" \
    GIT_COMMITTER_NAME="$AUTHOR_NAME" \
    GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL" \
    GIT_AUTHOR_DATE="$date" \
    GIT_COMMITTER_DATE="$date" \
    git commit -m "$msg"
}

rm -rf .git
git init -b main

# ============================================================
# Commit 1 - Jul 12 2025 - Initial project setup
# ============================================================

cat > .gitignore << 'GITIGNORE'
__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
.eggs/
*.egg
.venv/
venv/
env/
.env
db.json
*.db
.pytest_cache/
.ruff_cache/
.mypy_cache/
htmlcov/
.coverage
GITIGNORE

cat > LICENSE << 'LIC'
MIT License

Copyright (c) 2025 Lena Ivanova

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LIC

cat > requirements.txt << 'REQ'
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
tinydb>=4.8.0
jinja2>=3.1.2
REQ

mkdir -p moneymap
cat > moneymap/__init__.py << 'INIT'
__version__ = "0.1.0-dev"
INIT

commit_at "2025-07-12T10:23:14+00:00" "initial project setup" \
    .gitignore LICENSE requirements.txt moneymap/__init__.py

# ============================================================
# Commit 2 - Jul 15 2025 - FastAPI skeleton
# ============================================================

cat > moneymap/main.py << 'MAIN'
from fastapi import FastAPI

app = FastAPI(title="MoneyMap", version="0.1.0")


@app.get("/health")
def health():
    return {"status": "ok"}
MAIN

commit_at "2025-07-15T19:45:02+00:00" "add fastapi app skeleton" \
    moneymap/main.py

# ============================================================
# Commit 3 - Jul 20 2025 - Pydantic models
# ============================================================

cat > moneymap/models.py << 'MODELS'
from datetime import date, datetime
from enum import Enum
from pydantic import BaseModel, Field


class TxnType(str, Enum):
    income = "income"
    expense = "expense"


class TransactionCreate(BaseModel):
    amount: float = Field(..., gt=0)
    txn_type: TxnType
    category: str
    description: str = ""
    date: date = Field(default_factory=date.today)


class Transaction(TransactionCreate):
    id: int
    created_at: datetime


class MonthlySummary(BaseModel):
    year: int
    month: int
    total_income: float
    total_expense: float
    net: float
    txn_count: int


class CategoryBreakdown(BaseModel):
    category: str
    total: float
    percentage: float
    count: int


class AnalyticsResponse(BaseModel):
    period: str
    income: float
    expense: float
    net: float
    by_category: list[CategoryBreakdown]
MODELS

commit_at "2025-07-20T14:11:37+00:00" "define pydantic models for transactions and analytics" \
    moneymap/models.py

# ============================================================
# Commit 4 - Jul 28 2025 - TinyDB storage layer
# ============================================================

cat > moneymap/store.py << 'STORE'
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
STORE

commit_at "2025-07-28T21:32:50+00:00" "add tinydb storage layer" \
    moneymap/store.py

# ============================================================
# Commit 5 - Aug 5 2025 - Transaction routes
# ============================================================

mkdir -p moneymap/routers
cat > moneymap/routers/__init__.py << 'RINIT'
RINIT

cat > moneymap/routers/transactions.py << 'TXNR'
from fastapi import APIRouter, HTTPException
from typing import Optional

from moneymap.models import TransactionCreate, Transaction
from moneymap import store

router = APIRouter(prefix="/api/transactions", tags=["transactions"])


@router.post("/", response_model=Transaction, status_code=201)
def create_transaction(txn: TransactionCreate):
    data = txn.model_dump()
    data["date"] = txn.date.isoformat()
    result = store.insert_transaction(data)
    return result


@router.get("/")
def list_transactions(
    txn_type: Optional[str] = None,
    category: Optional[str] = None,
    year: Optional[int] = None,
    month: Optional[int] = None,
):
    txns = store.get_transactions(
        txn_type=txn_type,
        category=category,
        year=year,
        month=month,
    )
    return {"transactions": txns, "count": len(txns)}


@router.get("/{txn_id}")
def get_transaction(txn_id: int):
    txn = store.get_transaction_by_id(txn_id)
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return txn


@router.delete("/{txn_id}", status_code=204)
def delete_transaction(txn_id: int):
    ok = store.delete_transaction(txn_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Transaction not found")
TXNR

# update main.py to include router
cat > moneymap/main.py << 'MAIN2'
from fastapi import FastAPI
from moneymap.routers import transactions

app = FastAPI(title="MoneyMap", version="0.1.0")

app.include_router(transactions.router)


@app.get("/health")
def health():
    return {"status": "ok"}
MAIN2

commit_at "2025-08-05T18:07:22+00:00" "add transaction CRUD routes" \
    moneymap/routers/__init__.py moneymap/routers/transactions.py moneymap/main.py

# ============================================================
# Commit 6 - Aug 14 2025 - Analytics routes
# ============================================================

cat > moneymap/routers/analytics.py << 'ANALYTICS'
from collections import defaultdict
from fastapi import APIRouter
from typing import Optional

from moneymap import store
from moneymap.models import AnalyticsResponse, CategoryBreakdown, MonthlySummary

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


def _category_breakdown(txns: list[dict]) -> list[CategoryBreakdown]:
    totals: dict[str, float] = defaultdict(float)
    counts: dict[str, int] = defaultdict(int)

    for t in txns:
        cat = t.get("category", "uncategorized")
        totals[cat] += t["amount"]
        counts[cat] += 1

    grand = sum(totals.values()) or 1.0
    result = []
    for cat in sorted(totals.keys()):
        result.append(CategoryBreakdown(
            category=cat,
            total=round(totals[cat], 2),
            percentage=round(totals[cat] / grand * 100, 1),
            count=counts[cat],
        ))
    return result


@router.get("/monthly", response_model=AnalyticsResponse)
def monthly_analytics(year: int, month: int):
    txns = store.get_transactions(year=year, month=month)

    income = sum(t["amount"] for t in txns if t["txn_type"] == "income")
    expense = sum(t["amount"] for t in txns if t["txn_type"] == "expense")

    return AnalyticsResponse(
        period=f"{year}-{month:02d}",
        income=round(income, 2),
        expense=round(expense, 2),
        net=round(income - expense, 2),
        by_category=_category_breakdown(txns),
    )


@router.get("/yearly", response_model=AnalyticsResponse)
def yearly_analytics(year: int):
    txns = store.get_transactions(year=year)

    income = sum(t["amount"] for t in txns if t["txn_type"] == "income")
    expense = sum(t["amount"] for t in txns if t["txn_type"] == "expense")

    return AnalyticsResponse(
        period=str(year),
        income=round(income, 2),
        expense=round(expense, 2),
        net=round(income - expense, 2),
        by_category=_category_breakdown(txns),
    )


@router.get("/summary")
def monthly_summary(year: int) -> list[MonthlySummary]:
    """Month-by-month summary for a given year."""
    out = []
    for m in range(1, 13):
        txns = store.get_transactions(year=year, month=m)
        if not txns:
            continue
        inc = sum(t["amount"] for t in txns if t["txn_type"] == "income")
        exp = sum(t["amount"] for t in txns if t["txn_type"] == "expense")
        out.append(MonthlySummary(
            year=year, month=m,
            total_income=round(inc, 2),
            total_expense=round(exp, 2),
            net=round(inc - exp, 2),
            txn_count=len(txns),
        ))
    return out
ANALYTICS

# update main to include analytics
cat > moneymap/main.py << 'MAIN3'
from fastapi import FastAPI
from moneymap.routers import transactions, analytics

app = FastAPI(title="MoneyMap", version="0.1.0")

app.include_router(transactions.router)
app.include_router(analytics.router)


@app.get("/health")
def health():
    return {"status": "ok"}
MAIN3

commit_at "2025-08-14T11:52:18+00:00" "add analytics endpoints (monthly, yearly, summary)" \
    moneymap/routers/analytics.py moneymap/main.py

# ============================================================
# Commit 7 - Aug 23 2025 - Dashboard template
# ============================================================

cat > requirements.txt << 'REQ2'
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
tinydb>=4.8.0
jinja2>=3.1.2
python-multipart>=0.0.6
REQ2

mkdir -p moneymap/templates
cat > moneymap/templates/dashboard.html << 'DASH'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>MoneyMap</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; color: #333; }
        .container { max-width: 960px; margin: 0 auto; padding: 20px; }
        h1 { margin-bottom: 8px; }
        .subtitle { color: #666; margin-bottom: 24px; }
        .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 32px; }
        .card { background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .card h3 { font-size: 14px; color: #888; text-transform: uppercase; margin-bottom: 8px; }
        .card .value { font-size: 28px; font-weight: 600; }
        .card .value.positive { color: #2e7d32; }
        .card .value.negative { color: #c62828; }
        table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #fafafa; font-weight: 600; font-size: 13px; text-transform: uppercase; color: #666; }
        #error { color: #c62828; margin: 12px 0; display: none; }
        .controls { margin-bottom: 20px; display: flex; gap: 12px; align-items: center; }
        select, button { padding: 8px 12px; border-radius: 4px; border: 1px solid #ccc; font-size: 14px; }
        button { background: #1976d2; color: #fff; border: none; cursor: pointer; }
        button:hover { background: #1565c0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>MoneyMap</h1>
        <p class="subtitle">Income &amp; expense analytics</p>

        <div class="controls">
            <select id="year">
                <option value="2025" selected>2025</option>
            </select>
            <select id="month">
                <option value="">Full year</option>
                <option value="1">January</option>
                <option value="2">February</option>
                <option value="3">March</option>
                <option value="4">April</option>
                <option value="5">May</option>
                <option value="6">June</option>
                <option value="7">July</option>
                <option value="8">August</option>
                <option value="9">September</option>
                <option value="10">October</option>
                <option value="11">November</option>
                <option value="12">December</option>
            </select>
            <button onclick="loadData()">Load</button>
        </div>

        <div id="error"></div>

        <div class="cards">
            <div class="card">
                <h3>Income</h3>
                <div class="value positive" id="income">--</div>
            </div>
            <div class="card">
                <h3>Expenses</h3>
                <div class="value negative" id="expense">--</div>
            </div>
            <div class="card">
                <h3>Net</h3>
                <div class="value" id="net">--</div>
            </div>
        </div>

        <h2 style="margin-bottom: 12px;">Recent Transactions</h2>
        <table>
            <thead>
                <tr><th>Date</th><th>Type</th><th>Category</th><th>Amount</th></tr>
            </thead>
            <tbody id="txn-body">
                <tr><td colspan="4" style="text-align:center;color:#999;">Click Load to fetch data</td></tr>
            </tbody>
        </table>
    </div>

    <script>
        function fmt(n) {
            return '$' + Number(n).toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2});
        }

        async function loadData() {
            const year = document.getElementById('year').value;
            const month = document.getElementById('month').value;
            const errEl = document.getElementById('error');
            errEl.style.display = 'none';

            try {
                let url = month
                    ? '/api/analytics/monthly?year=' + year + '&month=' + month
                    : '/api/analytics/yearly?year=' + year;
                const resp = await fetch(url);
                const data = await resp.json();

                document.getElementById('income').textContent = fmt(data.income);
                document.getElementById('expense').textContent = fmt(data.expense);

                const netEl = document.getElementById('net');
                netEl.textContent = fmt(data.net);
                netEl.className = 'value ' + (data.net >= 0 ? 'positive' : 'negative');

                // load txns
                let txnUrl = '/api/transactions/?year=' + year;
                if (month) txnUrl += '&month=' + month;
                const txnResp = await fetch(txnUrl);
                const txnData = await txnResp.json();

                const tbody = document.getElementById('txn-body');
                if (txnData.transactions.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;color:#999;">No transactions</td></tr>';
                    return;
                }
                tbody.innerHTML = txnData.transactions.map(function(t) {
                    return '<tr><td>' + t.date + '</td><td>' + t.txn_type + '</td><td>' + t.category + '</td><td>' + fmt(t.amount) + '</td></tr>';
                }).join('');
            } catch (e) {
                errEl.textContent = 'Failed to load data: ' + e.message;
                errEl.style.display = 'block';
            }
        }
    </script>
</body>
</html>
DASH

cat > moneymap/main.py << 'MAIN4'
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from moneymap.routers import transactions, analytics

app = FastAPI(title="MoneyMap", version="0.1.0")

app.include_router(transactions.router)
app.include_router(analytics.router)

templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))


@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})


@app.get("/health")
def health():
    return {"status": "ok"}
MAIN4

commit_at "2025-08-23T15:38:44+00:00" "add jinja2 dashboard page" \
    requirements.txt moneymap/templates/dashboard.html moneymap/main.py

# ============================================================
# Commit 8 - Sep 2 2025 - Tests setup
# ============================================================

cat > requirements-dev.txt << 'RDEV'
-r requirements.txt
pytest>=7.4.0
httpx>=0.25.0
RDEV

mkdir -p tests
cat > tests/__init__.py << 'TINIT'
TINIT

cat > tests/conftest.py << 'CONF'
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
CONF

cat > tests/test_transactions.py << 'TTXN'
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
        "date": "2025-09-05",
    })
    assert resp.status_code == 201


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
TTXN

commit_at "2025-09-02T20:14:33+00:00" "add pytest setup and transaction tests" \
    requirements-dev.txt tests/__init__.py tests/conftest.py tests/test_transactions.py

# ============================================================
# Commit 9 - Sep 9 2025 - Analytics tests
# ============================================================

cat > tests/test_analytics.py << 'TANA'
def test_monthly_analytics(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/monthly?year=2025&month=10")
    assert resp.status_code == 200
    data = resp.json()
    assert data["period"] == "2025-10"
    assert data["income"] == 5000
    assert data["expense"] == 120.50
    assert data["net"] == 4879.50


def test_monthly_empty(client):
    resp = client.get("/api/analytics/monthly?year=2025&month=1")
    data = resp.json()
    assert data["income"] == 0
    assert data["expense"] == 0


def test_yearly_analytics(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/yearly?year=2025")
    data = resp.json()
    assert data["period"] == "2025"
    assert data["income"] == 5000
    assert data["expense"] == 120.50


def test_category_breakdown(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/monthly?year=2025&month=10")
    cats = resp.json()["by_category"]
    names = [c["category"] for c in cats]
    assert "salary" in names
    assert "groceries" in names


def test_yearly_summary(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/summary?year=2025")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["month"] == 10
    assert data[0]["txn_count"] == 2


def test_dashboard_loads(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "MoneyMap" in resp.text


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
TANA

commit_at "2025-09-09T17:26:51+00:00" "add analytics and dashboard tests" \
    tests/test_analytics.py

# ============================================================
# Commit 10 - Sep 18 2025 - GitHub Actions CI
# ============================================================

mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'CI'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - name: Install dependencies
        run: pip install -r requirements-dev.txt
      - name: Run tests
        run: pytest -v
CI

commit_at "2025-09-18T09:44:15+00:00" "add github actions CI workflow" \
    .github/workflows/ci.yml

# ============================================================
# Commit 11 - Sep 25 2025 - README
# ============================================================

cat > README.md << 'README'
# MoneyMap

Income and expense analytics API built with FastAPI and TinyDB.

Track transactions, categorize spending, and view analytics breakdowns by month, year, or category.

## Quickstart

```bash
pip install -r requirements.txt
uvicorn moneymap.main:app --reload
```

Open http://localhost:8000 for the dashboard, or http://localhost:8000/docs for the interactive API docs.

## API

### Transactions

- `POST /api/transactions/` - create a transaction
- `GET /api/transactions/` - list with optional filters (`txn_type`, `category`, `year`, `month`)
- `GET /api/transactions/{id}` - get single transaction
- `DELETE /api/transactions/{id}` - delete a transaction

### Analytics

- `GET /api/analytics/monthly?year=2025&month=10` - monthly breakdown
- `GET /api/analytics/yearly?year=2025` - yearly breakdown
- `GET /api/analytics/summary?year=2025` - month-by-month summary

## Transaction format

```json
{
  "amount": 120.50,
  "txn_type": "expense",
  "category": "groceries",
  "description": "Weekly shopping",
  "date": "2025-10-18"
}
```

`txn_type` is either `income` or `expense`. Amount must be positive.

## Running tests

```bash
pip install -r requirements-dev.txt
pytest
```

## License

MIT
README

commit_at "2025-09-25T13:02:40+00:00" "add README" \
    README.md

# ============================================================
# Commit 12 - Oct 3 2025 - version bump to 0.1.0
# ============================================================

cat > moneymap/__init__.py << 'V1'
__version__ = "0.1.0"
V1

commit_at "2025-10-03T10:17:28+00:00" "bump version to 0.1.0" \
    moneymap/__init__.py

# tag v0.1.0
GIT_COMMITTER_NAME="$AUTHOR_NAME" \
GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL" \
GIT_COMMITTER_DATE="2025-10-03T10:18:00+00:00" \
git tag -a v0.1.0 -m "v0.1.0 - initial release"

# ============================================================
# Commit 13 - Oct 19 2025 - Add tags to transactions
# ============================================================

cat > moneymap/models.py << 'MODELS2'
from datetime import date, datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class TxnType(str, Enum):
    income = "income"
    expense = "expense"


class TransactionCreate(BaseModel):
    amount: float = Field(..., gt=0)
    txn_type: TxnType
    category: str
    description: str = ""
    tags: list[str] = []
    date: date = Field(default_factory=date.today)


class Transaction(TransactionCreate):
    id: int
    created_at: datetime


class MonthlySummary(BaseModel):
    year: int
    month: int
    total_income: float
    total_expense: float
    net: float
    txn_count: int


class CategoryBreakdown(BaseModel):
    category: str
    total: float
    percentage: float
    count: int


class AnalyticsResponse(BaseModel):
    period: str
    income: float
    expense: float
    net: float
    by_category: list[CategoryBreakdown]


class TagGroup(BaseModel):
    tag: str
    total: float
    count: int
MODELS2

commit_at "2025-10-19T16:45:09+00:00" "add tags field to transaction model" \
    moneymap/models.py

# ============================================================
# Commit 14 - Oct 26 2025 - Tag filtering in store
# ============================================================

cat > moneymap/store.py << 'STORE2'
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
    tag: str | None = None,
    year: int | None = None,
    month: int | None = None,
) -> list[dict]:
    db = get_db()
    table = db.table("transactions")
    Txn = Query()

    results = table.all()

    if txn_type:
        results = [r for r in results if r.get("txn_type") == txn_type]
    if category:
        results = [r for r in results if r.get("category") == category]
    if tag:
        results = [r for r in results if tag in r.get("tags", [])]
    if year:
        results = [r for r in results if r.get("date", "").startswith(str(year))]
    if month and year:
        prefix = f"{year}-{month:02d}"
        results = [r for r in results if r.get("date", "").startswith(prefix)]

    # attach doc_id as id
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
STORE2

commit_at "2025-10-26T21:08:34+00:00" "support tag-based filtering in store layer" \
    moneymap/store.py

# ============================================================
# Commit 15 - Nov 4 2025 - Tag filter in transaction routes
# ============================================================

cat > moneymap/routers/transactions.py << 'TXNR2'
from fastapi import APIRouter, HTTPException, Query
from typing import Optional

from moneymap.models import TransactionCreate, Transaction
from moneymap import store

router = APIRouter(prefix="/api/transactions", tags=["transactions"])


@router.post("/", response_model=Transaction, status_code=201)
def create_transaction(txn: TransactionCreate):
    data = txn.model_dump()
    data["date"] = txn.date.isoformat()
    result = store.insert_transaction(data)
    return result


@router.get("/")
def list_transactions(
    txn_type: Optional[str] = None,
    category: Optional[str] = None,
    tag: Optional[str] = None,
    year: Optional[int] = None,
    month: Optional[int] = None,
):
    txns = store.get_transactions(
        txn_type=txn_type,
        category=category,
        tag=tag,
        year=year,
        month=month,
    )
    return {"transactions": txns, "count": len(txns)}


@router.get("/{txn_id}")
def get_transaction(txn_id: int):
    txn = store.get_transaction_by_id(txn_id)
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return txn


@router.delete("/{txn_id}", status_code=204)
def delete_transaction(txn_id: int):
    ok = store.delete_transaction(txn_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Transaction not found")
TXNR2

commit_at "2025-11-04T14:22:57+00:00" "add tag query param to transaction listing" \
    moneymap/routers/transactions.py

# ============================================================
# Commit 16 - Nov 15 2025 - Tag analytics endpoint
# ============================================================

cat > moneymap/routers/analytics.py << 'ANALYTICS2'
from collections import defaultdict
from fastapi import APIRouter, Query
from typing import Optional

from moneymap import store
from moneymap.models import AnalyticsResponse, CategoryBreakdown, MonthlySummary, TagGroup

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


def _category_breakdown(txns: list[dict]) -> list[CategoryBreakdown]:
    totals: dict[str, float] = defaultdict(float)
    counts: dict[str, int] = defaultdict(int)

    for t in txns:
        cat = t.get("category", "uncategorized")
        totals[cat] += t["amount"]
        counts[cat] += 1

    grand = sum(totals.values()) or 1.0
    result = []
    for cat in sorted(totals.keys()):
        result.append(CategoryBreakdown(
            category=cat,
            total=round(totals[cat], 2),
            percentage=round(totals[cat] / grand * 100, 1),
            count=counts[cat],
        ))
    return result


@router.get("/monthly", response_model=AnalyticsResponse)
def monthly_analytics(year: int, month: int):
    txns = store.get_transactions(year=year, month=month)

    income = sum(t["amount"] for t in txns if t["txn_type"] == "income")
    expense = sum(t["amount"] for t in txns if t["txn_type"] == "expense")

    return AnalyticsResponse(
        period=f"{year}-{month:02d}",
        income=round(income, 2),
        expense=round(expense, 2),
        net=round(income - expense, 2),
        by_category=_category_breakdown(txns),
    )


@router.get("/yearly", response_model=AnalyticsResponse)
def yearly_analytics(year: int):
    txns = store.get_transactions(year=year)

    income = sum(t["amount"] for t in txns if t["txn_type"] == "income")
    expense = sum(t["amount"] for t in txns if t["txn_type"] == "expense")

    return AnalyticsResponse(
        period=str(year),
        income=round(income, 2),
        expense=round(expense, 2),
        net=round(income - expense, 2),
        by_category=_category_breakdown(txns),
    )


@router.get("/summary")
def monthly_summary(year: int) -> list[MonthlySummary]:
    """Month-by-month summary for a given year."""
    out = []
    for m in range(1, 13):
        txns = store.get_transactions(year=year, month=m)
        if not txns:
            continue
        inc = sum(t["amount"] for t in txns if t["txn_type"] == "income")
        exp = sum(t["amount"] for t in txns if t["txn_type"] == "expense")
        out.append(MonthlySummary(
            year=year, month=m,
            total_income=round(inc, 2),
            total_expense=round(exp, 2),
            net=round(inc - exp, 2),
            txn_count=len(txns),
        ))
    return out


@router.get("/tags")
def tag_analytics(
    year: Optional[int] = None,
    month: Optional[int] = None,
    txn_type: Optional[str] = None,
) -> list[TagGroup]:
    txns = store.get_transactions(year=year, month=month, txn_type=txn_type)

    tag_totals: dict[str, float] = defaultdict(float)
    tag_counts: dict[str, int] = defaultdict(int)

    for t in txns:
        for tag in t.get("tags", []):
            tag_totals[tag] += t["amount"]
            tag_counts[tag] += 1

    return [
        TagGroup(tag=tag, total=round(total, 2), count=tag_counts[tag])
        for tag, total in sorted(tag_totals.items(), key=lambda x: -x[1])
    ]
ANALYTICS2

commit_at "2025-11-15T18:37:12+00:00" "add tag analytics endpoint" \
    moneymap/routers/analytics.py

# ============================================================
# Commit 17 - Nov 28 2025 - Update tests for tags
# ============================================================

cat > tests/conftest.py << 'CONF2'
import os
import pytest

# use a temp db for tests
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
        "tags": ["work", "recurring"],
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
        "tags": ["food", "recurring"],
        "date": "2025-10-18",
    })
    return resp.json()
CONF2

cat > tests/test_transactions.py << 'TTXN2'
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
TTXN2

cat > tests/test_analytics.py << 'TANA2'
def test_monthly_analytics(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/monthly?year=2025&month=10")
    assert resp.status_code == 200
    data = resp.json()
    assert data["period"] == "2025-10"
    assert data["income"] == 5000
    assert data["expense"] == 120.50
    assert data["net"] == 4879.50


def test_monthly_empty(client):
    resp = client.get("/api/analytics/monthly?year=2025&month=1")
    data = resp.json()
    assert data["income"] == 0
    assert data["expense"] == 0


def test_yearly_analytics(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/yearly?year=2025")
    data = resp.json()
    assert data["period"] == "2025"
    assert data["income"] == 5000
    assert data["expense"] == 120.50


def test_category_breakdown(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/monthly?year=2025&month=10")
    cats = resp.json()["by_category"]
    names = [c["category"] for c in cats]
    assert "salary" in names
    assert "groceries" in names

    # check percentages add up roughly
    total_pct = sum(c["percentage"] for c in cats)
    assert 99.9 < total_pct < 100.1


def test_yearly_summary(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/summary?year=2025")
    assert resp.status_code == 200
    data = resp.json()
    # should have one month with data
    assert len(data) == 1
    assert data[0]["month"] == 10
    assert data[0]["txn_count"] == 2


def test_tag_analytics(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/tags?year=2025")
    data = resp.json()
    tags = {t["tag"]: t for t in data}
    assert "recurring" in tags
    assert tags["recurring"]["count"] == 2
    assert tags["work"]["count"] == 1
    assert tags["food"]["count"] == 1


def test_tag_analytics_with_type_filter(client, sample_income, sample_expense):
    resp = client.get("/api/analytics/tags?year=2025&txn_type=expense")
    data = resp.json()
    tags = {t["tag"]: t for t in data}
    assert "food" in tags
    assert "work" not in tags


def test_dashboard_loads(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "MoneyMap" in resp.text


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
TANA2

commit_at "2025-11-28T12:51:06+00:00" "update tests for tag filtering" \
    tests/conftest.py tests/test_transactions.py tests/test_analytics.py

# ============================================================
# Commit 18 - Dec 11 2025 - Add ruff to CI
# ============================================================

cat > requirements-dev.txt << 'RDEV2'
-r requirements.txt
pytest>=7.4.0
httpx>=0.25.0
ruff>=0.1.0
RDEV2

cat > .github/workflows/ci.yml << 'CI2'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - name: Install dependencies
        run: pip install -r requirements-dev.txt
      - name: Run linter
        run: ruff check moneymap/ tests/
      - name: Run tests
        run: pytest -v
CI2

commit_at "2025-12-11T16:03:45+00:00" "add ruff linter to CI pipeline" \
    requirements-dev.txt .github/workflows/ci.yml

# ============================================================
# Commit 19 - Jan 8 2026 - Dashboard: add tags column + 2026 year option
# ============================================================

cat > moneymap/templates/dashboard.html << 'DASH2'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>MoneyMap</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; color: #333; }
        .container { max-width: 960px; margin: 0 auto; padding: 20px; }
        h1 { margin-bottom: 8px; }
        .subtitle { color: #666; margin-bottom: 24px; }
        .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 32px; }
        .card { background: #fff; border-radius: 8px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .card h3 { font-size: 14px; color: #888; text-transform: uppercase; margin-bottom: 8px; }
        .card .value { font-size: 28px; font-weight: 600; }
        .card .value.positive { color: #2e7d32; }
        .card .value.negative { color: #c62828; }
        table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #fafafa; font-weight: 600; font-size: 13px; text-transform: uppercase; color: #666; }
        .tag { display: inline-block; background: #e3f2fd; color: #1565c0; padding: 2px 8px; border-radius: 12px; font-size: 12px; margin-right: 4px; }
        #error { color: #c62828; margin: 12px 0; display: none; }
        .controls { margin-bottom: 20px; display: flex; gap: 12px; align-items: center; }
        select, button { padding: 8px 12px; border-radius: 4px; border: 1px solid #ccc; font-size: 14px; }
        button { background: #1976d2; color: #fff; border: none; cursor: pointer; }
        button:hover { background: #1565c0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>MoneyMap</h1>
        <p class="subtitle">Income &amp; expense analytics</p>

        <div class="controls">
            <select id="year">
                <option value="2025">2025</option>
                <option value="2026" selected>2026</option>
            </select>
            <select id="month">
                <option value="">Full year</option>
                <option value="1">January</option>
                <option value="2">February</option>
                <option value="3">March</option>
                <option value="4">April</option>
                <option value="5">May</option>
                <option value="6">June</option>
                <option value="7">July</option>
                <option value="8">August</option>
                <option value="9">September</option>
                <option value="10">October</option>
                <option value="11">November</option>
                <option value="12">December</option>
            </select>
            <button onclick="loadData()">Load</button>
        </div>

        <div id="error"></div>

        <div class="cards">
            <div class="card">
                <h3>Income</h3>
                <div class="value positive" id="income">--</div>
            </div>
            <div class="card">
                <h3>Expenses</h3>
                <div class="value negative" id="expense">--</div>
            </div>
            <div class="card">
                <h3>Net</h3>
                <div class="value" id="net">--</div>
            </div>
        </div>

        <h2 style="margin-bottom: 12px;">Recent Transactions</h2>
        <table>
            <thead>
                <tr><th>Date</th><th>Type</th><th>Category</th><th>Amount</th><th>Tags</th></tr>
            </thead>
            <tbody id="txn-body">
                <tr><td colspan="5" style="text-align:center;color:#999;">Click Load to fetch data</td></tr>
            </tbody>
        </table>
    </div>

    <script>
        function fmt(n) {
            return '$' + Number(n).toLocaleString(undefined, {minimumFractionDigits: 2, maximumFractionDigits: 2});
        }

        async function loadData() {
            const year = document.getElementById('year').value;
            const month = document.getElementById('month').value;
            const errEl = document.getElementById('error');
            errEl.style.display = 'none';

            try {
                let url = month
                    ? '/api/analytics/monthly?year=' + year + '&month=' + month
                    : '/api/analytics/yearly?year=' + year;
                const resp = await fetch(url);
                const data = await resp.json();

                document.getElementById('income').textContent = fmt(data.income);
                document.getElementById('expense').textContent = fmt(data.expense);

                const netEl = document.getElementById('net');
                netEl.textContent = fmt(data.net);
                netEl.className = 'value ' + (data.net >= 0 ? 'positive' : 'negative');

                // load txns
                let txnUrl = '/api/transactions/?year=' + year;
                if (month) txnUrl += '&month=' + month;
                const txnResp = await fetch(txnUrl);
                const txnData = await txnResp.json();

                const tbody = document.getElementById('txn-body');
                if (txnData.transactions.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:#999;">No transactions</td></tr>';
                    return;
                }
                tbody.innerHTML = txnData.transactions.map(function(t) {
                    var tagHtml = (t.tags || []).map(function(tag) {
                        return '<span class="tag">' + tag + '</span>';
                    }).join('');
                    return '<tr><td>' + t.date + '</td><td>' + t.txn_type + '</td><td>' + t.category + '</td><td>' + fmt(t.amount) + '</td><td>' + tagHtml + '</td></tr>';
                }).join('');
            } catch (e) {
                errEl.textContent = 'Failed to load data: ' + e.message;
                errEl.style.display = 'block';
            }
        }
    </script>
</body>
</html>
DASH2

commit_at "2026-01-08T11:19:33+00:00" "show tags in dashboard table, add 2026 year" \
    moneymap/templates/dashboard.html

# ============================================================
# Commit 20 - Jan 14 2026 - Version 0.2.0
# ============================================================

cat > moneymap/__init__.py << 'V2'
__version__ = "0.2.0"
V2

cat > moneymap/main.py << 'MAIN5'
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from moneymap.routers import transactions, analytics

app = FastAPI(title="MoneyMap", version="0.2.0")

app.include_router(transactions.router)
app.include_router(analytics.router)

templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))


@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})


@app.get("/health")
def health():
    return {"status": "ok"}
MAIN5

# update README with tag docs
cat > README.md << 'README2'
# MoneyMap

Income and expense analytics API built with FastAPI and TinyDB.

Track transactions, categorize spending, and view analytics breakdowns by month, year, category, or tag.

## Quickstart

```bash
pip install -r requirements.txt
uvicorn moneymap.main:app --reload
```

Open http://localhost:8000 for the dashboard, or http://localhost:8000/docs for the interactive API docs.

## API

### Transactions

- `POST /api/transactions/` - create a transaction
- `GET /api/transactions/` - list with optional filters (`txn_type`, `category`, `tag`, `year`, `month`)
- `GET /api/transactions/{id}` - get single transaction
- `DELETE /api/transactions/{id}` - delete a transaction

### Analytics

- `GET /api/analytics/monthly?year=2025&month=10` - monthly breakdown
- `GET /api/analytics/yearly?year=2025` - yearly breakdown
- `GET /api/analytics/summary?year=2025` - month-by-month summary
- `GET /api/analytics/tags?year=2025` - tag-based grouping

## Transaction format

```json
{
  "amount": 120.50,
  "txn_type": "expense",
  "category": "groceries",
  "description": "Weekly shopping",
  "tags": ["food", "recurring"],
  "date": "2025-10-18"
}
```

`txn_type` is either `income` or `expense`. Amount must be positive.

## Running tests

```bash
pip install -r requirements-dev.txt
pytest
```

## License

MIT
README2

commit_at "2026-01-14T09:42:18+00:00" "v0.2.0 - tag support, updated docs" \
    moneymap/__init__.py moneymap/main.py README.md

# tag v0.2.0
GIT_COMMITTER_NAME="$AUTHOR_NAME" \
GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL" \
GIT_COMMITTER_DATE="2026-01-14T09:43:00+00:00" \
git tag -a v0.2.0 -m "v0.2.0 - tags and filtering"

# ============================================================
# Commit 21 - Feb 3 2026 - Fix: percentage calc when no transactions
# ============================================================

# small inline fix in analytics - guard the empty case better
cat > moneymap/routers/analytics.py << 'ANALYTICS3'
from collections import defaultdict
from fastapi import APIRouter, Query
from typing import Optional

from moneymap import store
from moneymap.models import AnalyticsResponse, CategoryBreakdown, MonthlySummary, TagGroup

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


def _category_breakdown(txns: list[dict]) -> list[CategoryBreakdown]:
    if not txns:
        return []

    totals: dict[str, float] = defaultdict(float)
    counts: dict[str, int] = defaultdict(int)

    for t in txns:
        cat = t.get("category", "uncategorized")
        totals[cat] += t["amount"]
        counts[cat] += 1

    grand = sum(totals.values()) or 1.0
    result = []
    for cat in sorted(totals.keys()):
        result.append(CategoryBreakdown(
            category=cat,
            total=round(totals[cat], 2),
            percentage=round(totals[cat] / grand * 100, 1),
            count=counts[cat],
        ))
    return result


@router.get("/monthly", response_model=AnalyticsResponse)
def monthly_analytics(year: int, month: int):
    txns = store.get_transactions(year=year, month=month)

    income = sum(t["amount"] for t in txns if t["txn_type"] == "income")
    expense = sum(t["amount"] for t in txns if t["txn_type"] == "expense")

    return AnalyticsResponse(
        period=f"{year}-{month:02d}",
        income=round(income, 2),
        expense=round(expense, 2),
        net=round(income - expense, 2),
        by_category=_category_breakdown(txns),
    )


@router.get("/yearly", response_model=AnalyticsResponse)
def yearly_analytics(year: int):
    txns = store.get_transactions(year=year)

    income = sum(t["amount"] for t in txns if t["txn_type"] == "income")
    expense = sum(t["amount"] for t in txns if t["txn_type"] == "expense")

    return AnalyticsResponse(
        period=str(year),
        income=round(income, 2),
        expense=round(expense, 2),
        net=round(income - expense, 2),
        by_category=_category_breakdown(txns),
    )


@router.get("/summary")
def monthly_summary(year: int) -> list[MonthlySummary]:
    """Month-by-month summary for a given year."""
    out = []
    for m in range(1, 13):
        txns = store.get_transactions(year=year, month=m)
        if not txns:
            continue
        inc = sum(t["amount"] for t in txns if t["txn_type"] == "income")
        exp = sum(t["amount"] for t in txns if t["txn_type"] == "expense")
        out.append(MonthlySummary(
            year=year, month=m,
            total_income=round(inc, 2),
            total_expense=round(exp, 2),
            net=round(inc - exp, 2),
            txn_count=len(txns),
        ))
    return out


@router.get("/tags")
def tag_analytics(
    year: Optional[int] = None,
    month: Optional[int] = None,
    txn_type: Optional[str] = None,
) -> list[TagGroup]:
    txns = store.get_transactions(year=year, month=month, txn_type=txn_type)

    tag_totals: dict[str, float] = defaultdict(float)
    tag_counts: dict[str, int] = defaultdict(int)

    for t in txns:
        for tag in t.get("tags", []):
            tag_totals[tag] += t["amount"]
            tag_counts[tag] += 1

    return [
        TagGroup(tag=tag, total=round(total, 2), count=tag_counts[tag])
        for tag, total in sorted(tag_totals.items(), key=lambda x: -x[1])
    ]
ANALYTICS3

commit_at "2026-02-03T20:15:44+00:00" "fix category breakdown returning bogus data on empty months" \
    moneymap/routers/analytics.py

echo ""
echo "Done. $(git log --oneline | wc -l | tr -d ' ') commits created."
echo "Tags:"
git tag -l

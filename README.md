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

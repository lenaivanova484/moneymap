from fastapi import FastAPI
from moneymap.routers import transactions, analytics

app = FastAPI(title="MoneyMap", version="0.1.0")

app.include_router(transactions.router)
app.include_router(analytics.router)


@app.get("/health")
def health():
    return {"status": "ok"}

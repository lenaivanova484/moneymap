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

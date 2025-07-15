from fastapi import FastAPI

app = FastAPI(title="MoneyMap", version="0.1.0")


@app.get("/health")
def health():
    return {"status": "ok"}

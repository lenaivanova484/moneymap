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

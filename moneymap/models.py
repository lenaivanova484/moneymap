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

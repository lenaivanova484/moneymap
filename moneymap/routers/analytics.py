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

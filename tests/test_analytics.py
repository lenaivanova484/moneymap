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

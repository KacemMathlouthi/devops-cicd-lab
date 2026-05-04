import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


def test_root_returns_payload(client):
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["message"] == "hello from devops-cicd-lab"
    assert "hostname" in body
    assert isinstance(body["count"], int)


def test_healthz_returns_ok(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_metrics_exposes_request_counter(client):
    client.get("/")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"app_requests_total" in response.content

import socket

from fastapi import APIRouter, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

router = APIRouter()

REQUEST_COUNTER = Counter(
    "app_requests_total",
    "Total HTTP requests handled by the demo app",
    ["endpoint"],
)


@router.get("/")
def index():
    REQUEST_COUNTER.labels(endpoint="/").inc()
    return {
        "message": "hello from devops-cicd-lab",
        "hostname": socket.gethostname(),
        "count": int(REQUEST_COUNTER.labels(endpoint="/")._value.get()),
    }


@router.get("/healthz")
def healthz():
    return {"status": "ok"}


@router.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

"""Tests run against a real, throwaway PostgreSQL database: RLS is the point.

QMS_TEST_ADMIN_URL      owner connection to any database on the server (default: .../postgres)
The suite creates `qms_test`, applies every migration and the dev seed, then talks to it
through the API as the qms_api role, exactly like production.
"""

import os

import psycopg
import pytest

ADMIN_URL = os.environ.get("QMS_TEST_ADMIN_URL", "postgresql://qms_owner:qms@localhost:5432/postgres")
TEST_DB = "qms_test"
OWNER_URL = ADMIN_URL.rsplit("/", 1)[0] + f"/{TEST_DB}"
API_URL = os.environ.get("QMS_TEST_API_URL", f"postgresql://qms_api:qms_api@localhost:5432/{TEST_DB}")

os.environ["QMS_DATABASE_URL"] = API_URL
os.environ["QMS_OWNER_DATABASE_URL"] = OWNER_URL
os.environ["QMS_DEV_AUTH"] = "true"
os.environ["QMS_JWT_SECRET"] = "test-secret-" + "x" * 32

ALPHA = "a0000000-0000-4000-8000-000000000002"
BETA = "a0000000-0000-4000-8000-000000000003"
INTERNAL = "a0000000-0000-4000-8000-000000000001"


@pytest.fixture(scope="session")
def client():
    with psycopg.connect(ADMIN_URL, autocommit=True) as conn:
        conn.execute(f"DROP DATABASE IF EXISTS {TEST_DB} WITH (FORCE)")
        conn.execute(f"CREATE DATABASE {TEST_DB}")
    from fastapi.testclient import TestClient

    from qms_api.main import app
    from qms_api.migrate import migrate
    from qms_api.seed import seed

    migrate(OWNER_URL, verbose=False)
    seed("dev", OWNER_URL)
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="session")
def login(client):
    cache: dict[str, dict[str, str]] = {}

    def _login(email: str) -> dict[str, str]:
        if email not in cache:
            r = client.post("/api/auth/dev-login", json={"email": email})
            assert r.status_code == 200, r.text
            cache[email] = {"Authorization": f"Bearer {r.json()['access_token']}"}
        return cache[email]

    return _login

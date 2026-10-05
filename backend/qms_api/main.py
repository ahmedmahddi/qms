from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import DEV_JWT_SECRET, get_settings
from .crud import BadRequest
from .db import InactiveUser, close_pool, open_pool
from .errors import psycopg_exception_handler
from .meta import get_model
from .routes import auth, me, meta, records


@asynccontextmanager
async def lifespan(_: FastAPI):
    s = get_settings()
    if s.jwt_secret == DEV_JWT_SECRET and not s.dev_auth:
        raise RuntimeError("QMS_JWT_SECRET must be set outside development")
    get_model()
    open_pool()
    yield
    close_pool()


app = FastAPI(title="QMS API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=get_settings().cors_origins, allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

app.add_exception_handler(psycopg.Error, psycopg_exception_handler)


@app.exception_handler(BadRequest)
async def _bad_request(_: Request, exc: BadRequest) -> JSONResponse:
    return JSONResponse(status_code=400, content={"error": "bad_request", "detail": exc.detail,
                                                  "column": exc.column})


@app.exception_handler(PermissionError)
async def _forbidden(_: Request, exc: PermissionError) -> JSONResponse:
    return JSONResponse(status_code=403, content={"error": "forbidden", "detail": str(exc)})


@app.exception_handler(InactiveUser)
async def _inactive(_: Request, __: InactiveUser) -> JSONResponse:
    return JSONResponse(status_code=401, content={"error": "unauthorized", "detail": "inactive user"})


@app.get("/api/health")
def health() -> dict:
    return {"status": "ok"}


for r in (auth.router, me.router, meta.router, records.router):
    app.include_router(r, prefix="/api")

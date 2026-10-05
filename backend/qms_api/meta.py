"""Runtime view of the data model, loaded from db/generated/model.json (built by db/gen.py).

The generic records API and the frontend are both driven by this metadata, so a table added
to db/model.py is reachable end to end after regenerating the schema and migrating.
"""

import json
import re
from dataclasses import dataclass, field
from functools import lru_cache

from .config import get_settings

# Columns the server fills in; clients can never write them.
SERVER_COLUMNS = {"id", "organization_id", "created_at", "updated_at", "created_by"}

# Tables the generic API never writes: they have dedicated flows (login, invitations, uploads,
# the append-only trail, per-user notifications) or carry secrets.
NO_GENERIC_WRITE = {"users", "invitations", "files", "activity_log", "notifications", "import_jobs",
                    "export_jobs", "readiness_snapshots"}
# Tables the generic API does not expose at all.
HIDDEN = {"invitations"}

# Columns hidden from generic reads.
SECRET_COLUMNS = {("invitations", "token_hash"), ("users", "auth_subject")}


@dataclass(frozen=True)
class Column:
    name: str
    type: str
    nn: bool
    fk: str | None
    uq: bool
    pk: bool
    default: str | None
    comment: str

    @property
    def base_type(self) -> str:
        return self.type.removesuffix("[]")

    @property
    def is_array(self) -> bool:
        return self.type.endswith("[]")

    @property
    def required_on_create(self) -> bool:
        return self.nn and self.default is None and self.name not in SERVER_COLUMNS


@dataclass
class Table:
    name: str
    domain: str
    desc: str
    rls: str | None
    columns: dict[str, Column]
    uniques: list[list[str]]
    pk: list[str] = field(default_factory=list)

    @property
    def is_tenant(self) -> bool:
        c = self.columns.get("organization_id")
        return bool(c and c.nn and c.fk == "organizations")

    @property
    def is_link(self) -> bool:
        return self.pk != ["id"]

    @property
    def writable(self) -> bool:
        return self.name not in NO_GENERIC_WRITE

    def writable_columns(self) -> dict[str, Column]:
        return {n: c for n, c in self.columns.items() if n not in SERVER_COLUMNS}

    def readable_columns(self) -> list[str]:
        return [n for n in self.columns if (self.name, n) not in SECRET_COLUMNS]

    def label_sql(self, alias: str = "t") -> str:
        """SQL expression giving a human label for a row (used by lookups and search).

        Built only from model identifiers, never from request input.
        """
        a = alias
        cols = self.columns
        special = {
            "org_memberships": f"(SELECT u.full_name FROM users u WHERE u.id = {a}.user_id)",
            "firm_members": f"(SELECT u.full_name FROM users u WHERE u.id = {a}.user_id)",
            "standard_editions": f"(SELECT s.code FROM standards s WHERE s.id = {a}.standard_id) "
                                 f"|| ':' || {a}.edition",
            "clauses": f"{a}.number || ' ' || {a}.title",
            "document_versions": f"'rev. ' || {a}.revision",
        }
        if self.name in special:
            return special[self.name]
        for key, rest in (("code", ("name", "title", "label")), ("number", ("title", "name")),
                          ("reference", ("title",))):
            if key in cols:
                for r in rest:
                    if r in cols:
                        return f"coalesce({a}.{key} || ' — ', '') || {a}.{r}"
        for c in ("name", "title", "label", "full_name", "email", "number", "reference", "requirement",
                  "code", "edition", "activity"):
            if c in cols and cols[c].base_type == "text":
                return f"{a}.{c}"
        if "id" in cols:
            return f"{a}.id::text"
        return "''"

    def search_columns(self) -> list[str]:
        prefer = ("code", "number", "reference", "name", "title", "label", "full_name", "email",
                  "description", "requirement")
        return [c for c in prefer if c in self.columns and self.columns[c].type == "text"]


@dataclass
class Model:
    domains: dict[str, str]
    enums: dict[str, list[str]]
    tables: dict[str, Table]
    stats: dict

    def table(self, name: str) -> Table | None:
        t = self.tables.get(name)
        return None if t is None or t.name in HIDDEN else t

    def sql_type(self, col: Column) -> str:
        """Type usable in an explicit cast. Model types are validated by gen.py."""
        assert re.fullmatch(r"[a-z_0-9(),\[\]]+", col.type), col.type
        return col.type


@lru_cache
def get_model() -> Model:
    raw = json.loads(get_settings().model_json.read_text(encoding="utf-8"))
    tables: dict[str, Table] = {}
    for t in raw["dictionary"]:
        cols = {c["name"]: Column(name=c["name"], type=c["type"], nn=c["nn"], fk=c["fk"], uq=c["uq"],
                                  pk=c["pk"], default=c["default"], comment=c["comment"] or "")
                for c in t["cols"]}
        pk = [n for n, c in cols.items() if c.pk]
        tables[t["name"]] = Table(name=t["name"], domain=t["domain"], desc=t["desc"], rls=t["rls"],
                                  columns=cols, uniques=t["uniques"], pk=pk)
    return Model(domains=raw["domains"], enums=raw["enums"], tables=tables, stats=raw["stats"])

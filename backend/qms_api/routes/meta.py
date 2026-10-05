from fastapi import APIRouter

from ..auth import UserId
from ..meta import HIDDEN, get_model

router = APIRouter(tags=["meta"])


@router.get("/meta")
def meta(_: UserId) -> dict:
    m = get_model()
    tables = []
    for t in m.tables.values():
        if t.name in HIDDEN:
            continue
        readable = set(t.readable_columns())
        tables.append({
            "name": t.name, "domain": t.domain, "desc": t.desc, "rls": t.rls,
            "tenant": t.is_tenant, "link": t.is_link, "pk": t.pk, "writable": t.writable,
            "uniques": t.uniques,
            "columns": [{"name": c.name, "type": c.type, "base_type": c.base_type, "array": c.is_array,
                         "nn": c.nn, "fk": c.fk, "uq": c.uq, "pk": c.pk, "default": c.default,
                         "comment": c.comment, "required": c.required_on_create,
                         "enum": c.base_type in m.enums}
                        for c in t.columns.values() if c.name in readable],
        })
    return {"domains": m.domains, "enums": m.enums, "tables": tables, "stats": m.stats}

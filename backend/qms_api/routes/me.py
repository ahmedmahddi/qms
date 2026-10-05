from fastapi import APIRouter

from ..auth import UserId
from ..db import user_tx

router = APIRouter(tags=["me"])

ORGS_SQL = """
SELECT o.id, o.name, o.type, o.firm_id, f.name AS firm_name, o.firm_access, o.status,
       app.is_org_member(o.id) AS is_member,
       app.is_firm_side(o.id)  AS is_firm_side,
       app.can_write_org(o.id) AS can_write,
       coalesce((SELECT array_agg(DISTINCT p.code ORDER BY p.code)
                 FROM org_memberships m
                 JOIN membership_roles mr ON mr.membership_id = m.id
                 JOIN role_permissions rp ON rp.role_id = mr.role_id
                 JOIN permissions p ON p.id = rp.permission_id
                 WHERE m.organization_id = o.id AND m.user_id = app.current_user_id() AND m.is_active),
                '{}') AS permissions
FROM organizations o
JOIN firms f ON f.id = o.firm_id
ORDER BY o.type <> 'internal', o.name
"""


@router.get("/me")
def me(user_id: UserId) -> dict:
    with user_tx(user_id) as conn:
        user = conn.execute(
            "SELECT id, email, full_name, phone, locale, is_platform_admin, last_login_at "
            "FROM users WHERE id = %s", (user_id,)).fetchone()
        firms = conn.execute(
            "SELECT f.id, f.name, fm.role, fm.title FROM firm_members fm JOIN firms f ON f.id = fm.firm_id "
            "WHERE fm.user_id = %s AND fm.is_active ORDER BY f.name", (user_id,)).fetchall()
        orgs = conn.execute(ORGS_SQL).fetchall()
    return {"user": user, "firms": firms, "organizations": orgs}

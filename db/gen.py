import json, re, sys
from pathlib import Path
from collections import defaultdict, OrderedDict
from model import ENUMS, T, DOMAINS

OUT = Path(__file__).resolve().parent / "generated"
OUT.mkdir(exist_ok=True)

TABLES = OrderedDict()
for tb in T:
    if tb["name"] in TABLES:
        sys.exit(f"duplicate table {tb['name']}")
    TABLES[tb["name"]] = tb


def parse_col(spec):
    name, typ, flags, comment = (spec.split(":", 3) + ["", "", ""])[:4]
    c = {"name": name, "type": typ or "uuid", "nn": False, "fk": None, "del": None, "default": None,
         "uq": False, "comment": comment}
    for f in flags.split():
        if f == "nn":
            c["nn"] = True
        elif f == "uq":
            c["uq"] = True
        elif f.startswith("fk="):
            c["fk"] = f[3:]
        elif f.startswith("del="):
            c["del"] = f[4:]
        elif f.startswith("def="):
            c["default"] = f[4:]
        else:
            sys.exit(f"bad flag {f} in {spec}")
    return c


def is_tenant(tb):
    return tb["opt"].get("tenant", True)


# ---- build full column lists -------------------------------------------------
for tb in TABLES.values():
    o = tb["opt"]
    cols = []
    if not o.get("link"):
        cols.append({"name": "id", "type": "uuid", "nn": True, "fk": None, "del": None,
                     "default": "gen_random_uuid()", "uq": False, "comment": "Primary key", "pk": True})
    if is_tenant(tb):
        cols.append({"name": "organization_id", "type": "uuid", "nn": True, "fk": "organizations",
                     "del": "cascade", "default": None, "uq": False, "comment": "Tenant (client organization)"})
    for s in tb["cols"]:
        cols.append(parse_col(s))
    cols.append({"name": "created_at", "type": "timestamptz", "nn": True, "fk": None, "del": None,
                 "default": "now()", "uq": False, "comment": ""})
    if not o.get("no_audit"):
        cols.append({"name": "updated_at", "type": "timestamptz", "nn": True, "fk": None, "del": None,
                     "default": "now()", "uq": False, "comment": ""})
        cols.append({"name": "created_by", "type": "uuid", "nn": False, "fk": "users", "del": "setnull",
                     "default": None, "uq": False, "comment": ""})
    names = [c["name"] for c in cols]
    dup = {n for n in names if names.count(n) > 1}
    if dup:
        sys.exit(f"{tb['name']}: duplicate columns {dup}")
    tb["all"] = cols

# ---- validation ------------------------------------------------------------------
errors = []
for tb in TABLES.values():
    for c in tb["all"]:
        if c["fk"] and c["fk"] not in TABLES:
            errors.append(f"{tb['name']}.{c['name']} -> unknown table {c['fk']}")
        base = re.sub(r"\[\]$", "", c["type"])
        if not re.match(r"^(uuid|text|int|bigint|boolean|date|timestamptz|jsonb|inet|char\(\d+\)|numeric\(\d+,\d+\))$", base) \
                and base not in ENUMS:
            errors.append(f"{tb['name']}.{c['name']} unknown type {c['type']}")
        if c["fk"] and c["type"] != "uuid":
            errors.append(f"{tb['name']}.{c['name']} fk with non-uuid type")
    for u in tb["opt"].get("uniques", []):
        for col in u:
            if col not in [c["name"] for c in tb["all"]]:
                errors.append(f"{tb['name']} unique on unknown column {col}")
    for col in tb["opt"].get("link") or []:
        if col not in [c["name"] for c in tb["all"]]:
            errors.append(f"{tb['name']} pk on unknown column {col}")
if errors:
    print("\n".join(errors))
    sys.exit(1)

# ---- SQL ------------------------------------------------------------------------
Q = []
w = Q.append
w("-- =====================================================================================")
w("-- QMS platform — PostgreSQL 16 schema (generated from model.py — edit the model, not this file)")
w("-- Multi-tenant: firm (consulting company) → organizations (clients) → records.")
w("-- Tenant isolation: organization_id on every client table + composite FKs + Row-Level Security.")
w("-- The API sets per request:  SET LOCAL app.user_id = '<uuid>';")
w("-- =====================================================================================\n")
w("CREATE EXTENSION IF NOT EXISTS pgcrypto;")
w("CREATE SCHEMA IF NOT EXISTS app;\n")

w("-- ------------------------------------------------------------------ enums")
for e, vals in ENUMS.items():
    w(f"CREATE TYPE {e} AS ENUM ({', '.join(repr(v) for v in vals)});")
w("")


def q(x):
    return "'" + x.replace("'", "''") + "'"


def sql_default(d):
    return d


current_domain = None
for tb in TABLES.values():
    if tb["domain"] != current_domain:
        current_domain = tb["domain"]
        w(f"\n-- ================================================================== {DOMAINS[current_domain]}")
    lines = []
    for c in tb["all"]:
        s = f"  {c['name']} {c['type']}"
        if c.get("pk"):
            s += " PRIMARY KEY"
        if c["nn"] and not c.get("pk"):
            s += " NOT NULL"
        if c["default"]:
            s += f" DEFAULT {sql_default(c['default'])}"
        if c["uq"]:
            s += " UNIQUE"
        lines.append(s)
    o = tb["opt"]
    if o.get("link"):
        lines.append(f"  PRIMARY KEY ({', '.join(o['link'])})")
    if is_tenant(tb) and not o.get("link"):
        lines.append(f"  UNIQUE (organization_id, id)")
    for u in o.get("uniques", []):
        nullable = any(not next(c for c in tb["all"] if c["name"] == col)["nn"] for col in u)
        lines.append(f"  UNIQUE {'NULLS NOT DISTINCT ' if nullable else ''}({', '.join(u)})")
    for ck in o.get("checks", []):
        lines.append(f"  CHECK ({ck})")
    w(f"-- {tb['desc']}")
    w(f"CREATE TABLE {tb['name']} (\n" + ",\n".join(lines) + "\n);")
    for c in tb["all"]:
        if c["comment"]:
            w(f"COMMENT ON COLUMN {tb['name']}.{c['name']} IS " + q(c['comment']) + ";")
    w(f"COMMENT ON TABLE {tb['name']} IS '{tb['desc'].replace(chr(39), chr(39)*2)}';")

# ---- foreign keys (added after all tables → circular refs are fine) ------------
w("\n-- ================================================================== foreign keys")
w("-- Tenant→tenant references use composite keys (organization_id, x_id) so a row can never")
w("-- point to another client's data, even through a bug in the application layer.")
fk_list = []
for tb in TABLES.values():
    for c in tb["all"]:
        if not c["fk"] or c["name"] == "organization_id":
            continue
        parent = TABLES[c["fk"]]
        d = c["del"] or ("restrict" if c["nn"] else "setnull")
        composite = is_tenant(tb) and is_tenant(parent) and not parent["opt"].get("link")
        cname = f"fk_{tb['name']}_{c['name']}"[:63]
        if composite:
            ondel = {"cascade": "CASCADE", "restrict": "RESTRICT", "setnull": f"SET NULL ({c['name']})"}[d]
            w(f"ALTER TABLE {tb['name']} ADD CONSTRAINT {cname} FOREIGN KEY (organization_id, {c['name']}) "
              f"REFERENCES {parent['name']} (organization_id, id) ON DELETE {ondel};")
        else:
            ondel = {"cascade": "CASCADE", "restrict": "RESTRICT", "setnull": "SET NULL"}[d]
            w(f"ALTER TABLE {tb['name']} ADD CONSTRAINT {cname} FOREIGN KEY ({c['name']}) "
              f"REFERENCES {parent['name']} (id) ON DELETE {ondel};")
        fk_list.append((tb["name"], c["name"], parent["name"], c["nn"], c["uq"]))
    if is_tenant(tb):
        w(f"ALTER TABLE {tb['name']} ADD CONSTRAINT " + f"fk_{tb['name']}_org"[:63] + " FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;")
        fk_list.append((tb["name"], "organization_id", "organizations", True, False))

# ---- indexes ----------------------------------------------------------------------
w("\n-- ================================================================== indexes")
for tb in TABLES.values():
    pk = tb["opt"].get("link") or ["id"]
    for c in tb["all"]:
        if c["fk"] and c["name"] not in (pk[0],) and not c["uq"]:
            if c["name"] == "organization_id" and not tb["opt"].get("link"):
                continue  # covered by UNIQUE (organization_id, id)
            w("CREATE INDEX " + f"ix_{tb['name']}_{c['name']}"[:63] + f" ON {tb['name']} ({c['name']});")
# useful business indexes
w("CREATE INDEX ix_actions_open_due ON actions (organization_id, due_on) WHERE status IN ('planned','in_progress');")
w("CREATE INDEX ix_nc_open ON nonconformities (organization_id, status) WHERE status <> 'closed';")
w("CREATE INDEX ix_attachments_entity ON attachments (entity_type, entity_id);")
w("CREATE INDEX ix_comments_entity ON comments (entity_type, entity_id);")
w("CREATE INDEX ix_activity_entity ON activity_log (entity_type, entity_id, occurred_at DESC);")
w("CREATE INDEX ix_notifications_unread ON notifications (user_id) WHERE read_at IS NULL;")
w("CREATE INDEX ix_equipment_checks_due ON equipment_check_plans (organization_id, next_due_on) WHERE is_active;")
w("CREATE INDEX ix_documents_review ON documents (organization_id, next_review_on) WHERE status = 'approved';")
w("CREATE INDEX ix_register_entries_data ON register_entries USING gin (data);")
w("CREATE INDEX ix_regulatory_texts_search ON regulatory_texts USING gin (to_tsvector('french', coalesce(reference,'') || ' ' || title || ' ' || coalesce(summary,'')));")

# ---- functions ----------------------------------------------------------------------
w(r"""
-- ================================================================== access functions
CREATE OR REPLACE FUNCTION app.current_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('app.user_id', true), '')::uuid $$;

CREATE OR REPLACE FUNCTION app.is_platform_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce((SELECT is_platform_admin FROM users WHERE id = app.current_user_id()), false) $$;

CREATE OR REPLACE FUNCTION app.is_firm_member(p_firm uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM firm_members fm
                 WHERE fm.firm_id = p_firm AND fm.user_id = app.current_user_id() AND fm.is_active)
      OR app.is_platform_admin() $$;

CREATE OR REPLACE FUNCTION app.is_firm_admin(p_firm uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM firm_members fm
                 WHERE fm.firm_id = p_firm AND fm.user_id = app.current_user_id() AND fm.is_active
                   AND fm.role IN ('owner','admin'))
      OR app.is_platform_admin() $$;

-- Firm side of a client: firm owner/admin, or a consultant currently assigned to it.
CREATE OR REPLACE FUNCTION app.is_firm_side(p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM organizations o
    JOIN firm_members fm ON fm.firm_id = o.firm_id AND fm.user_id = app.current_user_id() AND fm.is_active
    WHERE o.id = p_org AND o.firm_access <> 'none'
      AND (fm.role IN ('owner','admin')
           OR EXISTS (SELECT 1 FROM consultant_assignments ca
                      WHERE ca.firm_member_id = fm.id AND ca.organization_id = p_org
                        AND ca.starts_on <= current_date
                        AND (ca.ends_on IS NULL OR ca.ends_on >= current_date))))
  OR app.is_platform_admin() $$;

CREATE OR REPLACE FUNCTION app.can_access_org(p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM org_memberships m
                 JOIN organizations o ON o.id = m.organization_id AND o.client_portal_enabled
                 WHERE m.organization_id = p_org AND m.user_id = app.current_user_id() AND m.is_active)
      OR app.is_firm_side(p_org) $$;

-- Write access: the client's own users always; the firm only while the client grants full access.
CREATE OR REPLACE FUNCTION app.is_org_member(p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM org_memberships m
                 JOIN organizations o ON o.id = m.organization_id AND o.client_portal_enabled
                 WHERE m.organization_id = p_org AND m.user_id = app.current_user_id() AND m.is_active) $$;

CREATE OR REPLACE FUNCTION app.can_write_org(p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT app.is_org_member(p_org)
      OR (app.is_firm_side(p_org) AND (SELECT firm_access = 'full' FROM organizations WHERE id = p_org))
      OR app.is_platform_admin() $$;

-- Only the client itself decides how much access the consulting firm keeps.
CREATE OR REPLACE FUNCTION app.guard_firm_access() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.firm_access IS DISTINCT FROM OLD.firm_access
     AND NOT (app.is_org_member(NEW.id) OR app.is_platform_admin()) THEN
    RAISE EXCEPTION 'firm_access can only be changed by the client organization';
  END IF;
  RETURN NEW;
END $$;

-- Approved and superseded document versions are frozen: edits go through a new revision.
CREATE OR REPLACE FUNCTION app.protect_approved_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status IN ('approved','superseded') THEN
    IF TG_OP = 'DELETE' THEN
      RAISE EXCEPTION 'approved document versions cannot be deleted; mark the document obsolete instead';
    END IF;
    IF NEW.status NOT IN ('approved','superseded')
       OR (to_jsonb(NEW) - 'status' - 'superseded_on' - 'updated_at')
          <> (to_jsonb(OLD) - 'status' - 'superseded_on' - 'updated_at') THEN
      RAISE EXCEPTION 'approved document versions are read-only; create a new revision';
    END IF;
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

-- Read access to a firm's library: its members, and users of its client organizations.
CREATE OR REPLACE FUNCTION app.can_read_firm(p_firm uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT app.is_firm_member(p_firm)
      OR EXISTS (SELECT 1 FROM org_memberships m JOIN organizations o ON o.id = m.organization_id
                 WHERE o.firm_id = p_firm AND m.user_id = app.current_user_id() AND m.is_active) $$;

CREATE OR REPLACE FUNCTION app.has_permission(p_org uuid, p_permission text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM org_memberships m
    JOIN membership_roles mr ON mr.membership_id = m.id
    JOIN role_permissions rp ON rp.role_id = mr.role_id
    JOIN permissions p ON p.id = rp.permission_id AND p.code = p_permission
    WHERE m.organization_id = p_org AND m.user_id = app.current_user_id() AND m.is_active)
  OR app.is_platform_admin() $$;

CREATE OR REPLACE FUNCTION app.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;
""")

# ---- RLS -------------------------------------------------------------------------------
w("-- ================================================================== row-level security")
GLOBAL_REF = {"standards", "standard_editions", "clauses", "clause_correspondences", "permissions",
              "substance_compatibility_rules", "role_permissions"}
LIB_NULLABLE = {"sectors", "regulatory_texts"}
FIRM_LIB = {"kits", "document_templates", "process_templates", "indicator_templates", "risk_templates",
            "clause_evidence_expectations", "certification_bodies"}
FIRM_OR_ORG = {"scoring_models", "register_definitions"}
CHILD_OF = {  # table: (parent, fk col)
    "scoring_dimensions": ("scoring_models", "model_id"),
    "scoring_bands": ("scoring_models", "model_id"),
    "kit_editions": ("kits", "kit_id"),
    "kit_items": ("kits", "kit_id"),
    "template_clauses": ("document_templates", "document_template_id"),
    "regulatory_requirements": ("regulatory_texts", "text_id"),
}
rls_kind = {}


def pol(table, name, cmd, using, check=None):
    if name == "p_write" and cmd == "ALL":
        # Never FOR ALL for writes: permissive policies are OR-ed per command, and a FOR ALL
        # policy also applies to SELECT, so its USING would widen what p_read lets through
        # (e.g. firm-internal comments becoming visible to every client user who can write).
        pol(table, "p_insert", "INSERT", None, check)
        pol(table, "p_update", "UPDATE", using, check)
        pol(table, "p_delete", "DELETE", using)
        return
    s = f"CREATE POLICY {name} ON {table} FOR {cmd}"
    if using:
        s += f" USING ({using})"
    if check:
        s += f" WITH CHECK ({check})"
    w(s + ";")


for tb in TABLES.values():
    n = tb["name"]
    w(f"ALTER TABLE {n} ENABLE ROW LEVEL SECURITY;")
    if n == "comments":
        rls_kind[n] = "tenant + firm-internal visibility"
        pol(n, "p_read", "SELECT", "app.can_access_org(organization_id) AND (visibility = 'shared' OR app.is_firm_side(organization_id))")
        cond = "app.can_write_org(organization_id) AND (visibility = 'shared' OR app.is_firm_side(organization_id))"
        pol(n, "p_write", "ALL", cond, cond)
    elif n == "medical_visits":
        rls_kind[n] = "tenant + permission hr.medical.read"
        pol(n, "p_all", "ALL", "app.has_permission(organization_id, 'hr.medical.read')",
            "app.has_permission(organization_id, 'hr.medical.read')")
    elif n == "incidents":
        rls_kind[n] = "tenant (victim identity hidden by API unless hr.incident.personal)"
        pol(n, "p_read", "SELECT", "app.can_access_org(organization_id)")
        pol(n, "p_write", "ALL", "app.can_write_org(organization_id)", "app.can_write_org(organization_id)")
    elif is_tenant(tb):
        rls_kind[n] = "tenant: client always reads & writes; firm per firm_access"
        pol(n, "p_read", "SELECT", "app.can_access_org(organization_id)")
        pol(n, "p_write", "ALL", "app.can_write_org(organization_id)", "app.can_write_org(organization_id)")
    elif n == "roles":
        rls_kind[n] = "system, firm or client custom roles"
        pol(n, "p_read", "SELECT", "(org_id IS NULL AND (firm_id IS NULL OR app.can_read_firm(firm_id))) OR (org_id IS NOT NULL AND app.can_access_org(org_id))")
        cond = "(org_id IS NOT NULL AND app.can_write_org(org_id)) OR (org_id IS NULL AND firm_id IS NOT NULL AND app.is_firm_admin(firm_id)) OR app.is_platform_admin()"
        pol(n, "p_write", "ALL", cond, cond)
    elif n in GLOBAL_REF:
        rls_kind[n] = "global reference (read all, write platform admin)"
        pol(n, "p_read", "SELECT", "true")
        pol(n, "p_write", "ALL", "app.is_platform_admin()", "app.is_platform_admin()")
    elif n in LIB_NULLABLE:
        rls_kind[n] = "global or firm library"
        pol(n, "p_read", "SELECT", "firm_id IS NULL OR app.can_read_firm(firm_id)")
        pol(n, "p_write", "ALL", "(firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id)",
            "(firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id)")
    elif n in FIRM_LIB:
        rls_kind[n] = "firm library"
        pol(n, "p_read", "SELECT", "app.can_read_firm(firm_id)")
        pol(n, "p_write", "ALL", "app.is_firm_member(firm_id)", "app.is_firm_member(firm_id)")
    elif n in FIRM_OR_ORG:
        rls_kind[n] = "firm template or org override"
        pol(n, "p_read", "SELECT", "(org_id IS NULL AND app.can_read_firm(firm_id)) OR (org_id IS NOT NULL AND app.can_access_org(org_id))")
        pol(n, "p_write", "ALL", "(org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id))",
            "(org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id))")
    elif n in CHILD_OF or n == "scoring_levels":
        rls_kind[n] = "inherits parent"
        if n == "scoring_levels":
            cond = ("EXISTS (SELECT 1 FROM scoring_dimensions d JOIN scoring_models m ON m.id = d.model_id "
                    "WHERE d.id = dimension_id AND ((m.org_id IS NULL AND app.can_read_firm(m.firm_id)) "
                    "OR (m.org_id IS NOT NULL AND app.can_access_org(m.org_id))))")
        else:
            parent, col = CHILD_OF[n]
            cond = f"EXISTS (SELECT 1 FROM {parent} p WHERE p.id = {col})"  # parent RLS applies inside
        wr = {
            "kits": "app.is_firm_member(p.firm_id)",
            "document_templates": "app.is_firm_member(p.firm_id)",
            "regulatory_texts": "((p.firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(p.firm_id))",
            "scoring_models": "((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))",
        }
        if n == "scoring_levels":
            wcond = ("EXISTS (SELECT 1 FROM scoring_dimensions d JOIN scoring_models p ON p.id = d.model_id "
                     f"WHERE d.id = dimension_id AND {wr['scoring_models']})")
        else:
            wcond = f"EXISTS (SELECT 1 FROM {parent} p WHERE p.id = {col} AND {wr[parent]})"
        pol(n, "p_read", "SELECT", cond)
        pol(n, "p_write", "ALL", wcond, wcond)
    elif n == "firms":
        rls_kind[n] = "members & clients read, admins write"
        pol(n, "p_read", "SELECT", "app.can_read_firm(id)")
        pol(n, "p_write", "UPDATE", "app.is_firm_admin(id)", "app.is_firm_admin(id)")
    elif n == "organizations":
        rls_kind[n] = "org access; firm admins create"
        pol(n, "p_read", "SELECT", "app.can_access_org(id)")
        pol(n, "p_insert", "INSERT", None, "app.is_firm_member(firm_id)")
        pol(n, "p_update", "UPDATE", "app.can_write_org(id)", "app.can_write_org(id)")
        w("CREATE TRIGGER trg_organizations_firm_access BEFORE UPDATE OF firm_access ON organizations FOR EACH ROW EXECUTE FUNCTION app.guard_firm_access();")
    elif n == "users":
        rls_kind[n] = "self + co-members"
        pol(n, "p_read", "SELECT", "id = app.current_user_id() OR app.is_platform_admin() OR EXISTS ("
            "SELECT 1 FROM org_memberships m WHERE m.user_id = users.id AND app.can_access_org(m.organization_id)) "
            "OR EXISTS (SELECT 1 FROM firm_members f WHERE f.user_id = users.id AND app.is_firm_member(f.firm_id))")
        pol(n, "p_update", "UPDATE", "id = app.current_user_id() OR app.is_platform_admin()",
            "id = app.current_user_id() OR app.is_platform_admin()")
    elif n == "firm_members":
        rls_kind[n] = "firm read, admin write"
        pol(n, "p_read", "SELECT", "app.can_read_firm(firm_id)")
        pol(n, "p_write", "ALL", "app.is_firm_admin(firm_id)", "app.is_firm_admin(firm_id)")
    elif n == "invitations":
        rls_kind[n] = "firm side or org"
        cond = "app.is_firm_member(firm_id) OR (target_org_id IS NOT NULL AND app.can_write_org(target_org_id))"
        pol(n, "p_all", "ALL", cond, cond)
    elif n in ("files",):
        rls_kind[n] = "org or firm"
        cond = "(org_id IS NOT NULL AND app.can_access_org(org_id)) OR (org_id IS NULL AND app.is_firm_member(firm_id))"
        pol(n, "p_all", "ALL", cond, cond)
    elif n == "activity_log":
        rls_kind[n] = "append-only, org or firm"
        cond = "(org_id IS NOT NULL AND app.can_access_org(org_id)) OR (org_id IS NULL AND app.is_firm_member(firm_id))"
        pol(n, "p_read", "SELECT", cond)
        pol(n, "p_insert", "INSERT", None, cond)
    elif n in ("notifications", "notification_preferences"):
        rls_kind[n] = "owner only"
        pol(n, "p_all", "ALL", "user_id = app.current_user_id()", "user_id = app.current_user_id()")
    else:
        sys.exit(f"no RLS rule for {n}")
    if n == "document_versions":
        w("CREATE TRIGGER trg_document_versions_lock BEFORE UPDATE OR DELETE ON document_versions FOR EACH ROW EXECUTE FUNCTION app.protect_approved_version();")
    if any(c["name"] == "updated_at" for c in tb["all"]):
        w(f"CREATE TRIGGER trg_{n}_touch BEFORE UPDATE ON {n} FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();")

w(r"""
-- ================================================================== views
-- Consolidated action plan with origin label and lateness.
CREATE VIEW v_action_plan WITH (security_invoker = true) AS
SELECT a.*,
       (a.status IN ('planned','in_progress') AND a.due_on < current_date) AS is_overdue,
       (a.status = 'done' AND a.efficacy_verified_on IS NULL
        AND coalesce(a.efficacy_due_on, a.completed_on + 30) < current_date) AS efficacy_check_overdue
FROM actions a;

-- Latest evaluation of every risk / hazard / aspect.
CREATE VIEW v_risk_register WITH (security_invoker = true) AS
SELECT r.*, e.phase AS last_phase, e.score AS last_score, e.band_id AS last_band_id,
       e.efficacy AS last_efficacy, e.evaluated_on AS last_evaluated_on
FROM risk_items r
LEFT JOIN LATERAL (SELECT * FROM risk_evaluations x WHERE x.risk_item_id = r.id
                   ORDER BY x.evaluated_on DESC, x.created_at DESC LIMIT 1) e ON true;

-- Master list of documented information (ID-QSE-015 equivalent).
CREATE VIEW v_master_list WITH (security_invoker = true) AS
SELECT d.organization_id, d.code, d.title, dt.label AS type, p.code AS process, v.revision,
       v.effective_on, d.status, d.next_review_on
FROM documents d
JOIN document_types dt ON dt.id = d.document_type_id
LEFT JOIN processes p ON p.id = d.process_id
LEFT JOIN document_versions v ON v.id = d.current_version_id;
""")

w("""-- ================================================================== seed: system roles & permissions
INSERT INTO roles (firm_id, scope, code, name, is_system) VALUES
 (NULL,'firm','firm_owner','Firm owner',true),
 (NULL,'firm','firm_admin','Firm admin',true),
 (NULL,'firm','consultant','Consultant',true),
 (NULL,'organization','org_admin','Client admin (users, roles, settings, firm access)',true),
 (NULL,'organization','qse_manager','QSE manager (R QSE)',true),
 (NULL,'organization','top_management','Top management (Gérant) — approver',true),
 (NULL,'organization','process_owner','Process owner (Pilote)',true),
 (NULL,'organization','internal_auditor','Internal auditor',true),
 (NULL,'organization','hr_manager','HR manager',true),
 (NULL,'organization','contributor','Contributor',true),
 (NULL,'organization','employee','Employee (read & acknowledge)',true),
 (NULL,'organization','viewer','Viewer',true);

INSERT INTO permissions (code, module) VALUES
 ('documents.write','documents'),('documents.verify','documents'),('documents.approve','documents'),
 ('risks.write','risks'),('compliance.write','compliance'),('objectives.write','objectives'),
 ('indicators.enter','objectives'),('nc.write','improvement'),('nc.close','improvement'),
 ('actions.write','improvement'),('actions.verify_efficacy','improvement'),('audits.plan','audits'),
 ('audits.conduct','audits'),('review.manage','review'),('hr.write','people'),('hr.medical.read','people'),
 ('hr.incident.personal','people'),('suppliers.write','operations'),('equipment.write','operations'),
 ('inspections.conduct','operations'),('settings.manage','platform'),('users.manage','platform'),
 ('roles.manage','platform'),('firm_access.manage','platform'),('registers.design','documents'),
 ('processes.write','processes'),('context.write','context');

-- Default permissions per system role (clients can clone and adjust into their own roles)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON
  (r.code = 'org_admin')
  OR (r.code IN ('qse_manager','consultant') AND p.code NOT IN ('hr.medical.read','settings.manage','users.manage','roles.manage','firm_access.manage'))
  OR (r.code = 'top_management' AND p.code IN ('documents.approve','review.manage','actions.verify_efficacy','nc.close','audits.plan','objectives.write','context.write'))
  OR (r.code = 'process_owner' AND p.code IN ('documents.write','processes.write','indicators.enter','nc.write','actions.write','risks.write','suppliers.write','equipment.write','inspections.conduct'))
  OR (r.code = 'internal_auditor' AND p.code IN ('audits.conduct','nc.write'))
  OR (r.code = 'hr_manager' AND p.code IN ('hr.write','hr.medical.read','hr.incident.personal','documents.write'))
  OR (r.code = 'contributor' AND p.code IN ('nc.write','actions.write','indicators.enter','inspections.conduct'))
WHERE r.firm_id IS NULL AND r.org_id IS NULL;
""")

open(OUT / "schema.sql", "w").write("\n".join(Q) + "\n")

# ---- Mermaid ER per domain -------------------------------------------------------------
HIDE_IN_DOMAIN = {"organizations", "firms", "users", "org_memberships", "firm_members", "files"}


def mtype(t_):
    t_ = re.sub(r"\(.*\)", "", t_).replace("[]", "_array")
    return t_


def entity_block(tb, full=False):
    rows = []
    fkcols = {c["name"] for c in tb["all"] if c["fk"]}
    link = tb["opt"].get("link") or []
    for c in tb["all"]:
        if c["name"] in ("created_at", "updated_at", "created_by"):
            continue
        if not full and c["name"] == "organization_id":
            continue
        keys = []
        if c.get("pk") or c["name"] in link:
            keys.append("PK")
        if c["name"] in fkcols:
            keys.append("FK")
        if c["uq"]:
            keys.append("UK")
        rows.append(f"    {mtype(c['type'])} {c['name']}{' ' + ','.join(keys) if keys else ''}")
    return f"  {tb['name']} {{\n" + "\n".join(rows) + "\n  }"


ER = {}
for dom in DOMAINS:
    tabs = [tb for tb in TABLES.values() if tb["domain"] == dom]
    names = {tb["name"] for tb in tabs}
    lines = ["erDiagram"]
    for tb in tabs:
        lines.append(entity_block(tb))
    seen = set()
    for (child, col, parent, nn, uq) in fk_list:
        if child not in names or col in ("organization_id", "created_by"):
            continue
        if parent in HIDE_IN_DOMAIN and dom != "platform":
            continue
        if parent not in names and dom != "platform":
            # cross-domain: keep only if parent is a core hub for readability
            pass
        key = (parent, child, col)
        if key in seen:
            continue
        seen.add(key)
        left = "||" if nn else "|o"
        right = "o|" if uq else "o{"
        lines.append(f'  {parent} {left}--{right} {child} : "{col}"')
    ER[dom] = "\n".join(lines)

# ---- Overview (domain map) ----------------------------------------------------------------
edges = defaultdict(int)
for (child, col, parent, nn, uq) in fk_list:
    a, b = TABLES[child]["domain"], TABLES[parent]["domain"]
    if a != b and parent not in HIDE_IN_DOMAIN:
        edges[(a, b)] += 1

dictionary = []
for tb in TABLES.values():
    dictionary.append({
        "name": tb["name"], "domain": tb["domain"], "desc": tb["desc"], "rls": rls_kind.get(tb["name"]),
        "cols": [{"name": c["name"], "type": c["type"], "nn": c["nn"], "fk": c["fk"], "uq": c["uq"],
                  "pk": bool(c.get("pk")) or c["name"] in (tb["opt"].get("link") or []),
                  "default": c["default"], "comment": c["comment"]} for c in tb["all"]],
        "uniques": tb["opt"].get("uniques", []), "checks": tb["opt"].get("checks", []),
    })

json.dump({"domains": DOMAINS, "er": ER, "edges": [[a, b, n] for (a, b), n in edges.items()],
           "dictionary": dictionary, "enums": ENUMS,
           "stats": {"tables": len(TABLES), "enums": len(ENUMS), "fks": len(fk_list),
                     "columns": sum(len(tb["all"]) for tb in TABLES.values())}},
          open(OUT / "model.json", "w"), ensure_ascii=False, indent=1)
print("tables", len(TABLES), "enums", len(ENUMS), "fks", len(fk_list),
      "cols", sum(len(tb["all"]) for tb in TABLES.values()))
print({d: sum(1 for tb in TABLES.values() if tb["domain"] == d) for d in DOMAINS})

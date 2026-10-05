"""Generic CRUD behaviour: validation, casting, audit trail, link tables."""

from conftest import ALPHA


def test_meta_describes_every_table(client, login):
    m = client.get("/api/meta", headers=login("qse@alpha.test")).json()
    names = {t["name"] for t in m["tables"]}
    assert {"nonconformities", "actions", "documents", "clauses"} <= names
    assert "invitations" not in names
    users = next(t for t in m["tables"] if t["name"] == "users")
    assert "auth_subject" not in {c["name"] for c in users["columns"]}


def test_crud_roundtrip_with_audit_trail(client, login):
    h = login("qse@alpha.test")
    base = f"/api/orgs/{ALPHA}/t/interested_parties"
    r = client.post(base, headers=h, json={"name": "Banque", "nature": "external", "influence": 2})
    assert r.status_code == 201, r.text
    row = r.json()
    assert row["organization_id"] == ALPHA and row["is_relevant"] is True and row["_label"] == "Banque"
    assert row["created_by"] == "b0000000-0000-4000-8000-000000000003"

    r = client.patch(f"{base}/{row['id']}", headers=h, json={"influence": 3})
    assert r.status_code == 200 and r.json()["influence"] == 3

    assert client.delete(f"{base}/{row['id']}", headers=h).status_code == 204
    assert client.get(f"{base}/{row['id']}", headers=h).status_code == 404

    log = client.get(f"/api/t/activity_log?entity_id={row['id']}&order=occurred_at", headers=h).json()["items"]
    assert [e["action"] for e in log] == ["create", "update", "delete"]
    assert log[1]["diff"] == {"before": {"influence": 2}, "after": {"influence": 3}}


def test_validation_errors(client, login):
    h = login("qse@alpha.test")
    base = f"/api/orgs/{ALPHA}/t/nonconformities"
    r = client.post(base, headers=h, json={"title": "x"})
    assert r.status_code == 400 and "number" in r.json()["detail"]
    r = client.post(base, headers=h, json={"number": "N", "title": "x", "detected_on": "2026-01-01",
                                           "source": "bogus"})
    assert r.status_code == 400 and r.json()["column"] == "source"
    r = client.post(base, headers=h, json={"number": "N", "title": "x", "detected_on": "not a date",
                                           "source": "other"})
    assert r.status_code == 400
    r = client.post(base, headers=h, json={"number": "N", "title": "x", "detected_on": "2026-01-01",
                                           "source": "other", "organization_id": ALPHA})
    assert r.status_code == 400 and r.json()["column"] == "organization_id"
    r = client.post(base, headers=h, json={"number": "NC-2026-001", "title": "dup",
                                           "detected_on": "2026-01-01", "source": "other"})
    assert r.status_code == 409 and r.json()["error"] == "duplicate"
    assert r.json()["column"] == "number" and r.json()["detail"] == "a record with the same number already exists"


def test_filters_search_order_paging(client, login):
    h = login("qse@alpha.test")
    base = f"/api/orgs/{ALPHA}/t/nonconformities"
    assert client.get(f"{base}?severity=major", headers=h).json()["total"] == 1
    assert client.get(f"{base}?q=coulisse", headers=h).json()["items"][0]["number"] == "NC-2026-001"
    page = client.get(f"{base}?order=-number&limit=1", headers=h).json()
    assert page["total"] == 2 and [x["number"] for x in page["items"]] == ["NC-2026-002"]
    assert client.get(f"{base}?nope=1", headers=h).status_code == 400
    assert client.get(f"{base}?order=nope", headers=h).status_code == 400


def test_enum_arrays_roundtrip(client, login):
    h = login("qse@alpha.test")
    r = client.post(f"/api/orgs/{ALPHA}/t/context_issues", headers=h,
                    json={"nature": "internal", "title": "arr", "systems": ["quality", "ohs"]})
    assert r.status_code == 201 and r.json()["systems"] == ["quality", "ohs"]
    r = client.post(f"/api/orgs/{ALPHA}/t/context_issues", headers=h,
                    json={"nature": "internal", "title": "arr", "systems": ["nope"]})
    assert r.status_code == 400


def test_link_table_create_and_delete(client, login):
    h = login("qse@alpha.test")
    clause = client.get("/api/t/clauses?number=8&limit=1", headers=h).json()["items"][0]
    proc = "a2000000-0000-4000-8000-000000000003"
    base = f"/api/orgs/{ALPHA}/t/process_clauses"
    r = client.post(base, headers=h, json={"process_id": proc, "clause_id": clause["id"]})
    assert r.status_code == 201, r.text
    assert client.get(f"{base}?process_id={proc}", headers=h).json()["total"] == 1
    assert client.delete(f"{base}?process_id={proc}&clause_id={clause['id']}", headers=h).status_code == 204
    assert client.get(f"{base}?process_id={proc}", headers=h).json()["total"] == 0


def test_wrong_scope_and_protected_tables(client, login):
    h = login("qse@alpha.test")
    assert client.get("/api/t/nonconformities", headers=h).status_code == 400
    assert client.get(f"/api/orgs/{ALPHA}/t/clauses", headers=h).status_code == 400
    assert client.get("/api/t/nope", headers=h).status_code == 404
    assert client.post("/api/t/users", headers=h, json={"email": "x@y", "full_name": "x"}).status_code == 405
    assert client.get("/api/t/invitations", headers=h).status_code == 404


def test_approved_document_versions_are_frozen(client, login):
    h = login("qse@alpha.test")
    types = client.get(f"/api/orgs/{ALPHA}/t/document_types?code=PRO", headers=h).json()["items"]
    doc = client.post(f"/api/orgs/{ALPHA}/t/documents", headers=h, json={
        "code": "PRO-QSE-001", "title": "Maîtrise des documents", "document_type_id": types[0]["id"]}).json()
    v = client.post(f"/api/orgs/{ALPHA}/t/document_versions", headers=h, json={
        "document_id": doc["id"], "revision": "00", "version_no": 1}).json()
    vurl = f"/api/orgs/{ALPHA}/t/document_versions/{v['id']}"
    assert client.patch(vurl, headers=h, json={"status": "approved"}).status_code == 200
    r = client.patch(vurl, headers=h, json={"change_summary": "sneaky edit"})
    assert r.status_code == 409 and "read-only" in r.json()["detail"]
    assert client.delete(vurl, headers=h).status_code == 409


def test_filter_operators(client, login):
    h = login("qse@alpha.test")
    base = f"/api/orgs/{ALPHA}/t/actions"
    assert client.get(f"{base}?status__in=planned,in_progress", headers=h).json()["total"] == 2
    assert client.get(f"{base}?status__ne=planned", headers=h).json()["total"] == 1
    assert client.get(f"{base}?due_on__lt=2026-10-01", headers=h).json()["items"][0]["number"] == "AC-2026-001"
    assert client.get(f"{base}?completed_on__isnull=true", headers=h).json()["total"] == 2
    assert client.get(f"{base}?completed_on__isnull=false", headers=h).json()["total"] == 0
    assert client.get(f"{base}?status__in=bogus", headers=h).status_code == 400
    assert client.get(f"{base}?status__like=x", headers=h).status_code == 400

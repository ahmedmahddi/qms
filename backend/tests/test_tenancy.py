"""Who can see and change what. These are the guarantees clients are sold on."""

from conftest import ALPHA, BETA, INTERNAL


def org_ids(client, headers):
    return {o["id"]: o for o in client.get("/api/me", headers=headers).json()["organizations"]}


def nc_numbers(client, headers, org):
    r = client.get(f"/api/orgs/{org}/t/nonconformities", headers=headers)
    assert r.status_code == 200, r.text
    return [x["number"] for x in r.json()["items"]]


def test_requires_token(client):
    assert client.get("/api/me").status_code == 401
    assert client.get(f"/api/orgs/{ALPHA}/t/actions", headers={"Authorization": "Bearer nope"}).status_code == 401


def test_unknown_user_cannot_log_in(client):
    assert client.post("/api/auth/dev-login", json={"email": "nobody@x.test"}).status_code == 401


def test_client_users_only_see_their_own_organization(client, login):
    alpha, beta = login("qse@alpha.test"), login("qse@beta.test")
    assert set(org_ids(client, alpha)) == {ALPHA}
    assert set(org_ids(client, beta)) == {BETA}
    assert sorted(nc_numbers(client, alpha, ALPHA)) == ["NC-2026-001", "NC-2026-002"]
    assert nc_numbers(client, alpha, BETA) == []
    assert nc_numbers(client, beta, ALPHA) == []


def test_record_of_another_tenant_is_not_found(client, login):
    nc = "a3000000-0000-4000-8000-000000000001"  # Alpha's NC
    assert client.get(f"/api/orgs/{ALPHA}/t/nonconformities/{nc}", headers=login("qse@alpha.test")).status_code == 200
    beta = login("qse@beta.test")
    assert client.get(f"/api/orgs/{BETA}/t/nonconformities/{nc}", headers=beta).status_code == 404
    assert client.get(f"/api/orgs/{ALPHA}/t/nonconformities/{nc}", headers=beta).status_code == 404
    assert client.patch(f"/api/orgs/{ALPHA}/t/nonconformities/{nc}", json={"title": "pwned"},
                        headers=beta).status_code == 404


def test_cannot_insert_into_another_tenant(client, login):
    r = client.post(f"/api/orgs/{ALPHA}/t/context_issues", json={"nature": "internal", "title": "x"},
                    headers=login("qse@beta.test"))
    assert r.status_code == 403


def test_cannot_reference_another_tenants_record(client, login):
    # Beta tries to hang an action off Alpha's nonconformity: the composite FK refuses it.
    r = client.post(f"/api/orgs/{BETA}/t/actions", headers=login("qse@beta.test"), json={
        "number": "AC-X", "title": "x", "type": "corrective",
        "nonconformity_id": "a3000000-0000-4000-8000-000000000001"})
    assert r.status_code == 409
    assert r.json()["error"] == "reference_error"


def test_firm_owner_sees_every_client_consultant_only_assigned_ones(client, login):
    assert set(org_ids(client, login("owner@atlas.test"))) == {INTERNAL, ALPHA, BETA}
    consultant = login("consultant@atlas.test")
    assert set(org_ids(client, consultant)) == {ALPHA}
    assert nc_numbers(client, consultant, BETA) == []


def test_read_only_firm_access_blocks_firm_writes(client, login):
    owner = login("owner@atlas.test")
    beta = org_ids(client, owner)[BETA]
    assert beta["firm_access"] == "read_only" and beta["can_write"] is False
    assert nc_numbers(client, owner, BETA) == ["NC-2026-001"]  # can still read
    r = client.post(f"/api/orgs/{BETA}/t/context_issues", json={"nature": "internal", "title": "x"},
                    headers=owner)
    assert r.status_code == 403
    nc = client.get(f"/api/orgs/{BETA}/t/nonconformities", headers=owner).json()["items"][0]
    r = client.patch(f"/api/orgs/{BETA}/t/nonconformities/{nc['id']}", json={"title": "x"}, headers=owner)
    assert r.status_code == 403
    r = client.delete(f"/api/orgs/{BETA}/t/nonconformities/{nc['id']}", headers=owner)
    assert r.status_code == 403


def test_only_the_client_can_change_firm_access(client, login):
    r = client.patch(f"/api/t/organizations/{ALPHA}", json={"firm_access": "none"},
                     headers=login("owner@atlas.test"))
    assert r.status_code == 409  # trigger: firm_access can only be changed by the client
    beta = login("qse@beta.test")
    r = client.patch(f"/api/t/organizations/{BETA}", json={"firm_access": "none"}, headers=beta)
    assert r.status_code == 200, r.text
    try:
        assert BETA not in org_ids(client, login("owner@atlas.test"))
    finally:
        assert client.patch(f"/api/t/organizations/{BETA}", json={"firm_access": "read_only"},
                            headers=beta).status_code == 200


def test_firm_internal_comments_are_hidden_from_client(client, login):
    nc = "a3000000-0000-4000-8000-000000000001"
    consultant, alpha = login("consultant@atlas.test"), login("qse@alpha.test")
    for vis in ("shared", "firm_internal"):
        r = client.post(f"/api/orgs/{ALPHA}/t/comments", headers=consultant, json={
            "entity_type": "nonconformities", "entity_id": nc, "body": f"{vis} note", "visibility": vis})
        assert r.status_code == 201, r.text
    seen_by_client = {c["body"] for c in client.get(
        f"/api/orgs/{ALPHA}/t/comments?entity_id={nc}", headers=alpha).json()["items"]}
    seen_by_firm = {c["body"] for c in client.get(
        f"/api/orgs/{ALPHA}/t/comments?entity_id={nc}", headers=consultant).json()["items"]}
    assert "shared note" in seen_by_client and "firm_internal note" not in seen_by_client
    assert {"shared note", "firm_internal note"} <= seen_by_firm
    # ...and a client user cannot post a firm-internal comment.
    r = client.post(f"/api/orgs/{ALPHA}/t/comments", headers=alpha, json={
        "entity_type": "nonconformities", "entity_id": nc, "body": "x", "visibility": "firm_internal"})
    assert r.status_code == 403

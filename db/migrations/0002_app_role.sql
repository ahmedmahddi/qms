-- =====================================================================================
-- Runtime role for the API.
-- The schema owner bypasses RLS (it owns the tables), so the API must never connect as
-- the owner. It connects as a login role that is a member of qms_app: no ownership, no
-- BYPASSRLS, only DML grants. Every policy in 0001 then applies to every query.
-- =====================================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qms_app') THEN
    CREATE ROLE qms_app NOLOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
END $$;

GRANT USAGE ON SCHEMA public, app TO qms_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO qms_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO qms_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO qms_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT EXECUTE ON FUNCTIONS TO qms_app;

-- Migration bookkeeping is not application data.
REVOKE ALL ON TABLE schema_migrations FROM qms_app;

-- The activity log is append-only, including for the API.
REVOKE UPDATE, DELETE ON activity_log FROM qms_app;

-- ------------------------------------------------------------------ authentication helpers
-- Login happens before app.user_id is known, so RLS would hide the users row. These two
-- functions are the only way the API reads or touches a user outside of a user context.
CREATE OR REPLACE FUNCTION app.user_for_login(p_email text)
RETURNS TABLE (id uuid, status record_status, auth_subject text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u.id, u.status, u.auth_subject FROM users u WHERE lower(u.email) = lower(p_email) $$;

CREATE OR REPLACE FUNCTION app.user_for_subject(p_subject text)
RETURNS TABLE (id uuid, status record_status)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u.id, u.status FROM users u WHERE u.auth_subject = p_subject $$;

CREATE OR REPLACE FUNCTION app.record_login(p_user uuid) RETURNS void
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = public AS $$
  UPDATE users SET last_login_at = now() WHERE id = p_user $$;

REVOKE ALL ON FUNCTION app.user_for_login(text), app.user_for_subject(text), app.record_login(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.user_for_login(text), app.user_for_subject(text), app.record_login(uuid) TO qms_app;

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_email_lower ON users (lower(email));

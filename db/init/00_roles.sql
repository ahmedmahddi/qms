-- Local development only (docker compose mounts this into /docker-entrypoint-initdb.d).
-- qms_owner owns the schema and is what the app connects as, like the owner role on Neon.
-- CREATEROLE lets migration 0002 create qms_app; CREATEDB lets the test suite build qms_test.
CREATE ROLE qms_owner LOGIN CREATEDB CREATEROLE PASSWORD 'qms';
CREATE DATABASE qms OWNER qms_owner;

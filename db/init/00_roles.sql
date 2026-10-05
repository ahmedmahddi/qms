-- Cluster-level roles for local development (run once by the postgres superuser;
-- docker-compose mounts this into /docker-entrypoint-initdb.d).
-- qms_owner owns the schema and runs migrations. qms_api is what the API logs in as:
-- a member of qms_app, which owns nothing and so is fully subject to RLS.
CREATE ROLE qms_owner LOGIN CREATEDB PASSWORD 'qms';  -- CREATEDB: the test suite builds a throwaway database
CREATE ROLE qms_app NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE qms_api LOGIN PASSWORD 'qms_api' NOSUPERUSER NOBYPASSRLS IN ROLE qms_app;
CREATE DATABASE qms OWNER qms_owner;

-- =====================================================================================
-- QMS platform — PostgreSQL 16 schema (generated from model.py — edit the model, not this file)
-- Multi-tenant: firm (consulting company) → organizations (clients) → records.
-- Tenant isolation: organization_id on every client table + composite FKs + Row-Level Security.
-- The API sets per request:  SET LOCAL app.user_id = '<uuid>';
-- =====================================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS app;

-- ------------------------------------------------------------------ enums
CREATE TYPE org_type AS ENUM ('client', 'internal', 'prospect');
CREATE TYPE firm_access AS ENUM ('full', 'read_only', 'none');
CREATE TYPE subscription_plan AS ENUM ('with_engagement', 'standalone', 'trial');
CREATE TYPE subscription_status AS ENUM ('trial', 'active', 'past_due', 'suspended', 'cancelled');
CREATE TYPE firm_role AS ENUM ('owner', 'admin', 'consultant');
CREATE TYPE role_scope AS ENUM ('firm', 'organization');
CREATE TYPE record_status AS ENUM ('active', 'archived');
CREATE TYPE site_type AS ENUM ('head_office', 'warehouse', 'workshop', 'worksite', 'zone', 'fleet', 'other');
CREATE TYPE comment_visibility AS ENUM ('shared', 'firm_internal');
CREATE TYPE job_status AS ENUM ('pending', 'mapping', 'validating', 'running', 'done', 'failed');
CREATE TYPE export_format AS ENUM ('docx', 'xlsx', 'pdf');
CREATE TYPE qse_system AS ENUM ('quality', 'ohs', 'environment', 'integrated');
CREATE TYPE edition_status AS ENUM ('draft', 'active', 'withdrawn');
CREATE TYPE doc_info_requirement AS ENUM ('none', 'maintain', 'retain', 'maintain_and_retain');
CREATE TYPE correspondence_type AS ENUM ('equivalent', 'modified', 'new', 'removed', 'split', 'merged');
CREATE TYPE regulatory_text_type AS ENUM ('law', 'decree', 'order', 'circular', 'code', 'standard', 'convention', 'other');
CREATE TYPE regulatory_status AS ENUM ('in_force', 'amended', 'repealed');
CREATE TYPE scoring_kind AS ENUM ('risk_opportunity', 'ohs', 'environmental', 'objective', 'action_efficacy', 'supplier');
CREATE TYPE dimension_role AS ENUM ('factor', 'mastery', 'efficacy');
CREATE TYPE kit_item_type AS ENUM ('document_template', 'process_template', 'register_definition', 'indicator_template', 'risk_template', 'scoring_model', 'competency', 'control_plan');
CREATE TYPE engagement_status AS ENUM ('prospect', 'diagnostic', 'design', 'deployment', 'internal_audit', 'mock_audit', 'certification', 'surveillance', 'closed', 'lost');
CREATE TYPE assignment_role AS ENUM ('lead', 'support', 'auditor', 'reviewer');
CREATE TYPE milestone_status AS ENUM ('planned', 'in_progress', 'done', 'late', 'cancelled');
CREATE TYPE deliverable_status AS ENUM ('todo', 'in_progress', 'in_review', 'delivered', 'accepted');
CREATE TYPE visit_mode AS ENUM ('onsite', 'remote');
CREATE TYPE gap_type AS ENUM ('initial', 'intermediate', 'pre_certification', 'transition');
CREATE TYPE gap_status AS ENUM ('conforming', 'partial', 'nonconforming', 'not_applicable', 'not_assessed');
CREATE TYPE certificate_status AS ENUM ('valid', 'suspended', 'withdrawn', 'expired');
CREATE TYPE issue_nature AS ENUM ('internal', 'external');
CREATE TYPE swot_type AS ENUM ('strength', 'weakness', 'opportunity', 'threat');
CREATE TYPE process_type AS ENUM ('management', 'operational', 'support');
CREATE TYPE review_conclusion AS ENUM ('effective', 'partially_effective', 'not_effective');
CREATE TYPE doc_category AS ENUM ('policy', 'process_sheet', 'procedure', 'instruction', 'manual', 'plan', 'list', 'form', 'record', 'external');
CREATE TYPE doc_status AS ENUM ('draft', 'in_review', 'approved', 'obsolete', 'archived');
CREATE TYPE version_status AS ENUM ('draft', 'in_verification', 'in_approval', 'approved', 'rejected', 'superseded');
CREATE TYPE approval_step AS ENUM ('writing', 'verification', 'approval');
CREATE TYPE approval_decision AS ENUM ('pending', 'approved', 'rejected', 'changes_requested');
CREATE TYPE confidentiality AS ENUM ('public', 'internal', 'restricted', 'confidential');
CREATE TYPE doc_source AS ENUM ('created', 'imported', 'external', 'from_template');
CREATE TYPE distribution_purpose AS ENUM ('application', 'information');
CREATE TYPE change_type AS ENUM ('process', 'organization', 'equipment', 'product_service', 'legal', 'document', 'site', 'supplier', 'other');
CREATE TYPE change_status AS ENUM ('requested', 'assessed', 'approved', 'implemented', 'verified', 'rejected');
CREATE TYPE risk_kind AS ENUM ('risk', 'opportunity', 'ohs_hazard', 'env_aspect');
CREATE TYPE assessment_kind AS ENUM ('risk_opportunity', 'ohs', 'environmental');
CREATE TYPE plan_status AS ENUM ('draft', 'approved', 'in_progress', 'closed');
CREATE TYPE activity_type AS ENUM ('office', 'worksite', 'workshop', 'storage', 'travel', 'other');
CREATE TYPE cause_category AS ENUM ('man', 'machine', 'method', 'material', 'environment', 'measurement');
CREATE TYPE eval_phase AS ENUM ('initial', 'residual', 'reassessment');
CREATE TYPE routine_type AS ENUM ('routine', 'non_routine');
CREATE TYPE env_condition AS ENUM ('normal', 'abnormal', 'emergency');
CREATE TYPE lifecycle_stage AS ENUM ('raw_material', 'design', 'production', 'transport', 'installation', 'use', 'end_of_life');
CREATE TYPE control_level AS ENUM ('control', 'influence');
CREATE TYPE session_status AS ENUM ('planned', 'done', 'postponed', 'cancelled');
CREATE TYPE obligation_source AS ENUM ('legal', 'customer', 'interested_party', 'voluntary', 'standard');
CREATE TYPE compliance_status AS ENUM ('compliant', 'partially_compliant', 'non_compliant', 'not_applicable', 'not_evaluated');
CREATE TYPE frequency AS ENUM ('daily', 'weekly', 'monthly', 'quarterly', 'semiannual', 'annual', 'biennial', 'ad_hoc');
CREATE TYPE objective_status AS ENUM ('planned', 'in_progress', 'achieved', 'partially_achieved', 'not_achieved', 'cancelled');
CREATE TYPE comparator AS ENUM ('gte', 'lte', 'eq', 'gt', 'lt', 'between');
CREATE TYPE nc_source AS ENUM ('internal_audit', 'external_audit', 'gap_assessment', 'indicator', 'customer_complaint', 'product_service', 'supplier', 'incident', 'emergency_drill', 'legal_compliance', 'inspection', 'management_review', 'worker_consultation', 'register_entry', 'other');
CREATE TYPE nc_severity AS ENUM ('major', 'minor', 'observation');
CREATE TYPE nc_status AS ENUM ('open', 'analysis', 'action_planned', 'in_progress', 'verification', 'closed', 'cancelled');
CREATE TYPE rca_method AS ENUM ('five_whys', 'ishikawa', 'five_m', 'fault_tree', 'other');
CREATE TYPE action_type AS ENUM ('correction', 'corrective', 'preventive', 'improvement', 'risk_treatment', 'opportunity', 'objective', 'compliance', 'other');
CREATE TYPE action_source AS ENUM ('nonconformity', 'risk', 'objective', 'audit_finding', 'management_review', 'gap_assessment', 'compliance', 'change', 'worker_meeting', 'emergency_drill', 'equipment_check', 'inspection', 'standalone');
CREATE TYPE action_status AS ENUM ('planned', 'in_progress', 'done', 'effective', 'ineffective', 'cancelled');
CREATE TYPE priority AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE incident_type AS ENUM ('lost_time_accident', 'no_lost_time_accident', 'first_aid', 'near_miss', 'occupational_disease', 'commute_accident', 'env_incident', 'property_damage');
CREATE TYPE incident_status AS ENUM ('reported', 'investigating', 'actions_planned', 'closed');
CREATE TYPE complaint_status AS ENUM ('received', 'analysing', 'answered', 'closed', 'rejected');
CREATE TYPE audit_type AS ENUM ('internal', 'supplier', 'mock', 'certification_stage1', 'certification_stage2', 'surveillance', 'recertification', 'transition', 'second_party');
CREATE TYPE audit_status AS ENUM ('planned', 'scheduled', 'in_progress', 'reporting', 'closed', 'cancelled');
CREATE TYPE audit_role AS ENUM ('lead_auditor', 'auditor', 'observer', 'technical_expert', 'auditee_guide');
CREATE TYPE checklist_result AS ENUM ('conforming', 'nonconforming', 'observation', 'not_audited');
CREATE TYPE finding_type AS ENUM ('major_nc', 'minor_nc', 'observation', 'improvement_opportunity', 'strength');
CREATE TYPE finding_status AS ENUM ('open', 'answered', 'accepted', 'closed');
CREATE TYPE review_status AS ENUM ('planned', 'preparing', 'held', 'minutes_approved');
CREATE TYPE mr_input AS ENUM ('previous_actions', 'context_changes', 'interested_party_needs', 'customer_satisfaction', 'objectives', 'process_performance', 'nonconformities', 'monitoring_results', 'audit_results', 'supplier_performance', 'resources', 'risk_actions', 'improvement_opportunities', 'compliance_obligations', 'ohs_incidents', 'worker_consultation', 'env_performance', 'communications');
CREATE TYPE mr_output AS ENUM ('improvement', 'system_change', 'resources', 'objectives', 'policy', 'other');
CREATE TYPE employee_status AS ENUM ('active', 'on_leave', 'left');
CREATE TYPE contract_type AS ENUM ('cdi', 'cdd', 'sivp', 'intern', 'interim', 'subcontractor');
CREATE TYPE competency_category AS ENUM ('technical', 'qse', 'managerial', 'regulatory_authorization', 'language', 'other');
CREATE TYPE need_source AS ENUM ('evaluation', 'new_hire', 'regulation', 'incident', 'nonconformity', 'objective', 'request');
CREATE TYPE session_kind AS ENUM ('training', 'awareness', 'induction', 'toolbox_talk', 'drill_briefing');
CREATE TYPE request_status AS ENUM ('draft', 'submitted', 'approved', 'rejected', 'done');
CREATE TYPE medical_visit_type AS ENUM ('hiring', 'periodic', 'return_to_work', 'on_request');
CREATE TYPE fitness AS ENUM ('fit', 'fit_with_restrictions', 'unfit', 'pending');
CREATE TYPE direction AS ENUM ('internal', 'external');
CREATE TYPE meeting_role AS ENUM ('worker_representative', 'manager', 'qse', 'guest');
CREATE TYPE supplier_category AS ENUM ('product', 'service', 'subcontractor', 'transport', 'training', 'laboratory', 'certification', 'other');
CREATE TYPE supplier_decision AS ENUM ('pending', 'approved', 'conditional', 'rejected');
CREATE TYPE evaluation_kind AS ENUM ('selection', 'periodic', 'post_incident');
CREATE TYPE equipment_category AS ENUM ('measuring_instrument', 'lifting', 'fire_protection', 'electrical_installation', 'vehicle', 'tool', 'pressure_equipment', 'collective_protection', 'other');
CREATE TYPE equipment_status AS ENUM ('in_service', 'out_of_service', 'under_repair', 'scrapped');
CREATE TYPE check_type AS ENUM ('calibration', 'verification', 'regulatory_inspection', 'preventive_maintenance', 'corrective_maintenance');
CREATE TYPE check_result AS ENUM ('pending', 'conforming', 'conforming_with_reservations', 'nonconforming');
CREATE TYPE reservation_status AS ENUM ('open', 'lifted');
CREATE TYPE control_plan_kind AS ENUM ('receiving', 'in_process', 'final', 'hse_inspection', 'site_quality', 'other');
CREATE TYPE inspection_status AS ENUM ('planned', 'in_progress', 'done', 'cancelled');
CREATE TYPE point_result AS ENUM ('ok', 'nok', 'na');
CREATE TYPE project_status AS ENUM ('tender', 'planned', 'in_progress', 'reception', 'closed', 'cancelled');
CREATE TYPE resource_type AS ENUM ('electricity', 'water', 'fuel', 'gas', 'paper', 'other');
CREATE TYPE compat_rule AS ENUM ('compatible', 'segregate', 'forbidden');


-- ================================================================== Platform, tenancy & access
-- The consulting firm operating the platform (root tenant).
CREATE TABLE firms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  legal_name text,
  tax_id text,
  country char(2) NOT NULL DEFAULT 'TN',
  city text,
  logo_file_id uuid,
  settings jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN firms.id IS 'Primary key';
COMMENT ON COLUMN firms.tax_id IS 'Matricule fiscal';
COMMENT ON COLUMN firms.settings IS 'Branding, numbering defaults, locale';
COMMENT ON TABLE firms IS 'The consulting firm operating the platform (root tenant).';
-- Client companies (and the firm's own internal organization).
CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  name text NOT NULL,
  legal_name text,
  type org_type NOT NULL DEFAULT 'client',
  sector_id uuid,
  tax_id text,
  address text,
  city text,
  country char(2) NOT NULL DEFAULT 'TN',
  headcount int,
  activity_description text,
  logo_file_id uuid,
  status record_status NOT NULL DEFAULT 'active',
  onboarded_on date,
  client_portal_enabled boolean NOT NULL DEFAULT true,
  firm_access firm_access NOT NULL DEFAULT 'full',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN organizations.id IS 'Primary key';
COMMENT ON COLUMN organizations.client_portal_enabled IS 'Whether client users can log in';
COMMENT ON COLUMN organizations.firm_access IS 'Consultant access, set by the client (full, read_only, none)';
COMMENT ON TABLE organizations IS 'Client companies (and the firm''s own internal organization).';
-- Physical locations of a client: head office, warehouse, worksites (chantiers), zones.
CREATE TABLE sites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  parent_site_id uuid,
  code text,
  name text NOT NULL,
  type site_type NOT NULL,
  address text,
  city text,
  is_temporary boolean NOT NULL DEFAULT false,
  starts_on date,
  ends_on date,
  status record_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN sites.id IS 'Primary key';
COMMENT ON COLUMN sites.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN sites.parent_site_id IS 'Zone inside a site';
COMMENT ON COLUMN sites.is_temporary IS 'Worksite';
COMMENT ON TABLE sites IS 'Physical locations of a client: head office, warehouse, worksites (chantiers), zones.';
-- Global identities (one person can be a consultant and/or belong to several client orgs).
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  full_name text NOT NULL,
  phone text,
  locale text NOT NULL DEFAULT 'fr',
  auth_subject text UNIQUE,
  is_platform_admin boolean NOT NULL DEFAULT false,
  status record_status NOT NULL DEFAULT 'active',
  last_login_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN users.id IS 'Primary key';
COMMENT ON COLUMN users.auth_subject IS 'External IdP subject';
COMMENT ON TABLE users IS 'Global identities (one person can be a consultant and/or belong to several client orgs).';
-- Consultants and admins of the firm.
CREATE TABLE firm_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role firm_role NOT NULL,
  title text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (firm_id, user_id)
);
COMMENT ON COLUMN firm_members.id IS 'Primary key';
COMMENT ON TABLE firm_members IS 'Consultants and admins of the firm.';
-- A user's access to one client organization.
CREATE TABLE org_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  user_id uuid NOT NULL,
  job_title text,
  is_active boolean NOT NULL DEFAULT true,
  invited_by uuid,
  joined_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, user_id)
);
COMMENT ON COLUMN org_memberships.id IS 'Primary key';
COMMENT ON COLUMN org_memberships.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE org_memberships IS 'A user''s access to one client organization.';
-- RBAC roles: system roles, custom firm roles, and custom roles a client creates for itself.
CREATE TABLE roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid,
  org_id uuid,
  scope role_scope NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  description text,
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE NULLS NOT DISTINCT (firm_id, org_id, code),
  CHECK (NOT (firm_id IS NOT NULL AND org_id IS NOT NULL))
);
COMMENT ON COLUMN roles.id IS 'Primary key';
COMMENT ON COLUMN roles.firm_id IS 'Custom firm role';
COMMENT ON COLUMN roles.org_id IS 'Custom client role';
COMMENT ON TABLE roles IS 'RBAC roles: system roles, custom firm roles, and custom roles a client creates for itself.';
-- Permission catalogue, e.g. documents.approve, hr.medical.read.
CREATE TABLE permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  module text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN permissions.id IS 'Primary key';
COMMENT ON TABLE permissions IS 'Permission catalogue, e.g. documents.approve, hr.medical.read.';
-- Permissions granted by a role.
CREATE TABLE role_permissions (
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (role_id, permission_id)
);
COMMENT ON TABLE role_permissions IS 'Permissions granted by a role.';
-- Roles held by a client member, optionally scoped to one process (process owner of PCS-ACH).
CREATE TABLE membership_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  membership_id uuid NOT NULL,
  role_id uuid NOT NULL,
  process_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE NULLS NOT DISTINCT (membership_id, role_id, process_id)
);
COMMENT ON COLUMN membership_roles.id IS 'Primary key';
COMMENT ON COLUMN membership_roles.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN membership_roles.process_id IS 'Scope to one process';
COMMENT ON TABLE membership_roles IS 'Roles held by a client member, optionally scoped to one process (process owner of PCS-ACH).';
-- The client's own licence to use the platform, independent of any consulting engagement.
CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  plan subscription_plan NOT NULL,
  status subscription_status NOT NULL DEFAULT 'active',
  seats int,
  modules text[] NOT NULL DEFAULT '{}',
  engagement_id uuid,
  starts_on date NOT NULL DEFAULT CURRENT_DATE,
  ends_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN subscriptions.id IS 'Primary key';
COMMENT ON COLUMN subscriptions.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN subscriptions.modules IS 'Enabled modules';
COMMENT ON COLUMN subscriptions.engagement_id IS 'Bundled with an engagement';
COMMENT ON TABLE subscriptions IS 'The client''s own licence to use the platform, independent of any consulting engagement.';
-- Which consultants work on which client.
CREATE TABLE consultant_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  firm_member_id uuid NOT NULL,
  role assignment_role NOT NULL DEFAULT 'support',
  starts_on date NOT NULL DEFAULT CURRENT_DATE,
  ends_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, firm_member_id, starts_on)
);
COMMENT ON COLUMN consultant_assignments.id IS 'Primary key';
COMMENT ON COLUMN consultant_assignments.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE consultant_assignments IS 'Which consultants work on which client.';
-- Pending invitations to a firm or client org.
CREATE TABLE invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  target_org_id uuid,
  email text NOT NULL,
  role_id uuid NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  accepted_at timestamptz,
  invited_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN invitations.id IS 'Primary key';
COMMENT ON COLUMN invitations.target_org_id IS 'NULL = firm invite';
COMMENT ON TABLE invitations IS 'Pending invitations to a firm or client org.';
-- Binary objects in object storage (S3/MinIO).
CREATE TABLE files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  org_id uuid,
  storage_key text NOT NULL UNIQUE,
  filename text NOT NULL,
  mime_type text NOT NULL,
  size_bytes bigint NOT NULL,
  sha256 text NOT NULL,
  virus_scanned_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN files.id IS 'Primary key';
COMMENT ON TABLE files IS 'Binary objects in object storage (S3/MinIO).';
-- Links a file to any record (evidence, photo, signed PV, certificate).
CREATE TABLE attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  file_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  label text,
  category text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN attachments.id IS 'Primary key';
COMMENT ON COLUMN attachments.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN attachments.category IS 'evidence, photo, signed_copy, certificate…';
COMMENT ON TABLE attachments IS 'Links a file to any record (evidence, photo, signed PV, certificate).';
-- Threaded comments on any record. firm_internal = hidden from client users.
CREATE TABLE comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  parent_id uuid,
  body text NOT NULL,
  visibility comment_visibility NOT NULL DEFAULT 'shared',
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN comments.id IS 'Primary key';
COMMENT ON COLUMN comments.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE comments IS 'Threaded comments on any record. firm_internal = hidden from client users.';
-- In-app / email notifications.
CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  org_id uuid,
  type text NOT NULL,
  title text NOT NULL,
  body text,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  emailed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN notifications.id IS 'Primary key';
COMMENT ON TABLE notifications IS 'In-app / email notifications.';
-- Per-user channel preferences by event type.
CREATE TABLE notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_type text NOT NULL,
  in_app boolean NOT NULL DEFAULT true,
  email boolean NOT NULL DEFAULT true,
  digest frequency,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, event_type)
);
COMMENT ON COLUMN notification_preferences.id IS 'Primary key';
COMMENT ON TABLE notification_preferences IS 'Per-user channel preferences by event type.';
-- Append-only audit trail of every change (who, what, before/after).
CREATE TABLE activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  org_id uuid,
  actor_user_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  diff jsonb,
  ip_address inet,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN activity_log.id IS 'Primary key';
COMMENT ON COLUMN activity_log.action IS 'create, update, approve, sign, export…';
COMMENT ON TABLE activity_log IS 'Append-only audit trail of every change (who, what, before/after).';
-- Excel/Word imports of a client's existing registers.
CREATE TABLE import_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  kind text NOT NULL,
  file_id uuid NOT NULL,
  mapping jsonb NOT NULL DEFAULT '{}',
  status job_status NOT NULL DEFAULT 'pending',
  stats jsonb,
  errors jsonb,
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN import_jobs.id IS 'Primary key';
COMMENT ON COLUMN import_jobs.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN import_jobs.kind IS 'e.g. nonconformity_register, risk_manual, legal_watch';
COMMENT ON TABLE import_jobs IS 'Excel/Word imports of a client''s existing registers.';
-- Generated Word/Excel/PDF with the controlled-document header block.
CREATE TABLE export_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  document_template_id uuid,
  entity_type text NOT NULL,
  entity_id uuid,
  format export_format NOT NULL,
  file_id uuid,
  status job_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN export_jobs.id IS 'Primary key';
COMMENT ON COLUMN export_jobs.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE export_jobs IS 'Generated Word/Excel/PDF with the controlled-document header block.';

-- ================================================================== Standards & regulatory reference
-- Activity sectors (agro-alimentaire, BTP, industrie, services, énergie…).
CREATE TABLE sectors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid,
  code text NOT NULL,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE NULLS NOT DISTINCT (firm_id, code)
);
COMMENT ON COLUMN sectors.id IS 'Primary key';
COMMENT ON COLUMN sectors.firm_id IS 'NULL = global';
COMMENT ON TABLE sectors IS 'Activity sectors (agro-alimentaire, BTP, industrie, services, énergie…).';
-- ISO 9001, ISO 14001, ISO 45001 (and future ones).
CREATE TABLE standards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  system qse_system NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN standards.id IS 'Primary key';
COMMENT ON COLUMN standards.code IS 'e.g. ISO9001';
COMMENT ON TABLE standards IS 'ISO 9001, ISO 14001, ISO 45001 (and future ones).';
-- Editions: 9001:2015, 9001:2026, 14001:2015, 45001:2018…
CREATE TABLE standard_editions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  standard_id uuid NOT NULL,
  edition text NOT NULL,
  published_on date,
  transition_deadline date,
  status edition_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (standard_id, edition)
);
COMMENT ON COLUMN standard_editions.id IS 'Primary key';
COMMENT ON TABLE standard_editions IS 'Editions: 9001:2015, 9001:2026, 14001:2015, 45001:2018…';
-- Clause tree per edition. Store titles + the firm's own paraphrase, not ISO text.
CREATE TABLE clauses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  edition_id uuid NOT NULL,
  parent_id uuid,
  number text NOT NULL,
  title text NOT NULL,
  summary text,
  documented_info doc_info_requirement NOT NULL DEFAULT 'none',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (edition_id, number)
);
COMMENT ON COLUMN clauses.id IS 'Primary key';
COMMENT ON COLUMN clauses.number IS 'e.g. 8.5.1';
COMMENT ON COLUMN clauses.summary IS 'Firm paraphrase';
COMMENT ON TABLE clauses IS 'Clause tree per edition. Store titles + the firm''s own paraphrase, not ISO text.';
-- Maps clauses across editions (2015→2026) and across standards (harmonized structure).
CREATE TABLE clause_correspondences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_clause_id uuid NOT NULL,
  to_clause_id uuid NOT NULL,
  type correspondence_type NOT NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (from_clause_id, to_clause_id)
);
COMMENT ON COLUMN clause_correspondences.id IS 'Primary key';
COMMENT ON TABLE clause_correspondences IS 'Maps clauses across editions (2015→2026) and across standards (harmonized structure).';
-- Legal library (JORT texts…). Global rows shared across every client.
CREATE TABLE regulatory_texts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid,
  jurisdiction char(2) NOT NULL DEFAULT 'TN',
  type regulatory_text_type NOT NULL,
  reference text NOT NULL,
  title text NOT NULL,
  published_on date,
  official_journal_ref text,
  domain text,
  systems qse_system[] NOT NULL DEFAULT '{}',
  summary text,
  source_url text,
  status regulatory_status NOT NULL DEFAULT 'in_force',
  amended_by_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN regulatory_texts.id IS 'Primary key';
COMMENT ON COLUMN regulatory_texts.firm_id IS 'NULL = global library';
COMMENT ON COLUMN regulatory_texts.reference IS 'e.g. Décret n°2000-1985';
COMMENT ON TABLE regulatory_texts IS 'Legal library (JORT texts…). Global rows shared across every client.';
-- Individual obligations extracted from a text.
CREATE TABLE regulatory_requirements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  text_id uuid NOT NULL,
  article text,
  requirement text NOT NULL,
  applicability_criteria text,
  expected_evidence text,
  default_frequency frequency,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN regulatory_requirements.id IS 'Primary key';
COMMENT ON TABLE regulatory_requirements IS 'Individual obligations extracted from a text.';
-- Hazardous substance storage compatibility matrix (by hazard class).
CREATE TABLE substance_compatibility_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_a text NOT NULL,
  class_b text NOT NULL,
  rule compat_rule NOT NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (class_a, class_b)
);
COMMENT ON COLUMN substance_compatibility_rules.id IS 'Primary key';
COMMENT ON TABLE substance_compatibility_rules IS 'Hazardous substance storage compatibility matrix (by hazard class).';

-- ================================================================== Firm library & kits
-- Configurable scoring grids (G×P×D, F×G×M…). Firm default or org override.
CREATE TABLE scoring_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  org_id uuid,
  kind scoring_kind NOT NULL,
  name text NOT NULL,
  formula text NOT NULL,
  version int NOT NULL DEFAULT 1,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN scoring_models.id IS 'Primary key';
COMMENT ON COLUMN scoring_models.org_id IS 'NULL = firm default';
COMMENT ON COLUMN scoring_models.formula IS 'e.g. G*P*D';
COMMENT ON TABLE scoring_models IS 'Configurable scoring grids (G×P×D, F×G×M…). Firm default or org override.';
-- Dimensions of a model: G, P, D, F, mastery, efficacy.
CREATE TABLE scoring_dimensions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  role dimension_role NOT NULL DEFAULT 'factor',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (model_id, code)
);
COMMENT ON COLUMN scoring_dimensions.id IS 'Primary key';
COMMENT ON TABLE scoring_dimensions IS 'Dimensions of a model: G, P, D, F, mastery, efficacy.';
-- Levels of a dimension (1 = Très rare … 4 = Fréquent).
CREATE TABLE scoring_levels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dimension_id uuid NOT NULL,
  value numeric(6,2) NOT NULL,
  label text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (dimension_id, value)
);
COMMENT ON COLUMN scoring_levels.id IS 'Primary key';
COMMENT ON TABLE scoring_levels IS 'Levels of a dimension (1 = Très rare … 4 = Fréquent).';
-- Score ranges → priority (1–8 = Priorité 3, 16–64 = Priorité 1).
CREATE TABLE scoring_bands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid NOT NULL,
  min_score numeric(8,2) NOT NULL,
  max_score numeric(8,2) NOT NULL,
  label text NOT NULL,
  priority int NOT NULL,
  color text,
  requires_action boolean NOT NULL DEFAULT false,
  review_frequency frequency,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN scoring_bands.id IS 'Primary key';
COMMENT ON TABLE scoring_bands IS 'Score ranges → priority (1–8 = Priorité 3, 16–64 = Priorité 1).';
-- A certification kit: everything needed to start a client for given standards and sector.
CREATE TABLE kits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  name text NOT NULL,
  sector_id uuid,
  description text,
  version int NOT NULL DEFAULT 1,
  status record_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN kits.id IS 'Primary key';
COMMENT ON TABLE kits IS 'A certification kit: everything needed to start a client for given standards and sector.';
-- Standards covered by a kit.
CREATE TABLE kit_editions (
  kit_id uuid NOT NULL,
  edition_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (kit_id, edition_id)
);
COMMENT ON TABLE kit_editions IS 'Standards covered by a kit.';
-- Contents of a kit (templates of every type).
CREATE TABLE kit_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kit_id uuid NOT NULL,
  item_type kit_item_type NOT NULL,
  item_id uuid NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN kit_items.id IS 'Primary key';
COMMENT ON TABLE kit_items IS 'Contents of a kit (templates of every type).';
-- Master procedures, forms, manuals with coding pattern and clause links.
CREATE TABLE document_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  category doc_category NOT NULL,
  type_code text NOT NULL,
  code_pattern text NOT NULL,
  title text NOT NULL,
  content jsonb,
  file_id uuid,
  version int NOT NULL DEFAULT 1,
  status record_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN document_templates.id IS 'Primary key';
COMMENT ON COLUMN document_templates.type_code IS 'e.g. PRO, ID, MAN';
COMMENT ON COLUMN document_templates.code_pattern IS 'e.g. {TYPE}-{PCS}-{SEQ:3}';
COMMENT ON COLUMN document_templates.content IS 'Rich-text body';
COMMENT ON COLUMN document_templates.file_id IS 'DOCX/XLSX layout with header block';
COMMENT ON TABLE document_templates IS 'Master procedures, forms, manuals with coding pattern and clause links.';
-- Clauses a template helps satisfy.
CREATE TABLE template_clauses (
  document_template_id uuid NOT NULL,
  clause_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (document_template_id, clause_id)
);
COMMENT ON TABLE template_clauses IS 'Clauses a template helps satisfy.';
-- Standard process sheets per sector (PCS-QSE, PCS-ACH…).
CREATE TABLE process_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  sector_id uuid,
  code text NOT NULL,
  name text NOT NULL,
  type process_type NOT NULL,
  purpose text,
  default_steps jsonb NOT NULL DEFAULT '[]',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN process_templates.id IS 'Primary key';
COMMENT ON TABLE process_templates IS 'Standard process sheets per sector (PCS-QSE, PCS-ACH…).';
-- Standard KPIs attached to process templates.
CREATE TABLE indicator_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  process_template_id uuid,
  name text NOT NULL,
  formula text,
  unit text,
  comparator comparator,
  default_target numeric(12,4),
  frequency frequency,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN indicator_templates.id IS 'Primary key';
COMMENT ON TABLE indicator_templates IS 'Standard KPIs attached to process templates.';
-- Library of typical risks, hazards and aspects by sector/activity.
CREATE TABLE risk_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  sector_id uuid,
  kind risk_kind NOT NULL,
  activity text,
  title text NOT NULL,
  cause text,
  consequence text,
  typical_controls text,
  hazard_family text,
  aspect text,
  impact text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN risk_templates.id IS 'Primary key';
COMMENT ON TABLE risk_templates IS 'Library of typical risks, hazards and aspects by sector/activity.';
-- What evidence the firm expects per clause (drives readiness).
CREATE TABLE clause_evidence_expectations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  clause_id uuid NOT NULL,
  expected_evidence text NOT NULL,
  document_template_id uuid,
  weight numeric(5,2) NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN clause_evidence_expectations.id IS 'Primary key';
COMMENT ON TABLE clause_evidence_expectations IS 'What evidence the firm expects per clause (drives readiness).';

-- ================================================================== Consulting engagements & certification
-- Bureau Veritas, TÜV, AFNOR…
CREATE TABLE certification_bodies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  name text NOT NULL,
  accreditation text,
  contact text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN certification_bodies.id IS 'Primary key';
COMMENT ON TABLE certification_bodies IS 'Bureau Veritas, TÜV, AFNOR…';
-- A consulting mission for a client (one or several standards).
CREATE TABLE engagements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  name text NOT NULL,
  status engagement_status NOT NULL DEFAULT 'prospect',
  kit_id uuid,
  lead_consultant_id uuid,
  certification_body_id uuid,
  contract_ref text,
  scope_summary text,
  started_on date,
  target_certification_on date,
  closed_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN engagements.id IS 'Primary key';
COMMENT ON COLUMN engagements.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE engagements IS 'A consulting mission for a client (one or several standards).';
-- Standards targeted by an engagement.
CREATE TABLE engagement_editions (
  organization_id uuid NOT NULL,
  engagement_id uuid NOT NULL,
  edition_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (engagement_id, edition_id)
);
COMMENT ON COLUMN engagement_editions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE engagement_editions IS 'Standards targeted by an engagement.';
-- Phases and key dates of the mission.
CREATE TABLE engagement_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  engagement_id uuid NOT NULL,
  phase engagement_status NOT NULL,
  name text NOT NULL,
  planned_on date,
  done_on date,
  status milestone_status NOT NULL DEFAULT 'planned',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN engagement_milestones.id IS 'Primary key';
COMMENT ON COLUMN engagement_milestones.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE engagement_milestones IS 'Phases and key dates of the mission.';
-- What the consultant owes the client.
CREATE TABLE deliverables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  engagement_id uuid NOT NULL,
  milestone_id uuid,
  title text NOT NULL,
  document_id uuid,
  owner_id uuid,
  due_on date,
  delivered_on date,
  status deliverable_status NOT NULL DEFAULT 'todo',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN deliverables.id IS 'Primary key';
COMMENT ON COLUMN deliverables.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE deliverables IS 'What the consultant owes the client.';
-- Visits / sessions with the client (time tracking + minutes).
CREATE TABLE consultant_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  engagement_id uuid NOT NULL,
  firm_member_id uuid NOT NULL,
  visit_on date NOT NULL,
  hours numeric(5,2) NOT NULL DEFAULT 0,
  mode visit_mode NOT NULL DEFAULT 'onsite',
  agenda text,
  summary text,
  next_steps text,
  billable boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN consultant_visits.id IS 'Primary key';
COMMENT ON COLUMN consultant_visits.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE consultant_visits IS 'Visits / sessions with the client (time tracking + minutes).';
-- Diagnostic against a standard edition.
CREATE TABLE gap_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  engagement_id uuid,
  edition_id uuid NOT NULL,
  type gap_type NOT NULL,
  title text NOT NULL,
  assessed_on date,
  assessor_id uuid,
  status plan_status NOT NULL DEFAULT 'draft',
  overall_score numeric(5,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN gap_assessments.id IS 'Primary key';
COMMENT ON COLUMN gap_assessments.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE gap_assessments IS 'Diagnostic against a standard edition.';
-- One line per clause: status, evidence, recommendation.
CREATE TABLE gap_assessment_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  gap_assessment_id uuid NOT NULL,
  clause_id uuid NOT NULL,
  status gap_status NOT NULL DEFAULT 'not_assessed',
  score numeric(3,2),
  finding text,
  evidence text,
  recommendation text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (gap_assessment_id, clause_id)
);
COMMENT ON COLUMN gap_assessment_items.id IS 'Primary key';
COMMENT ON COLUMN gap_assessment_items.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN gap_assessment_items.score IS '0..1';
COMMENT ON TABLE gap_assessment_items IS 'One line per clause: status, evidence, recommendation.';
-- Computed certification readiness per edition, kept as history.
CREATE TABLE readiness_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  edition_id uuid NOT NULL,
  computed_at timestamptz NOT NULL DEFAULT now(),
  overall_score numeric(5,2) NOT NULL,
  by_clause jsonb NOT NULL,
  open_major_nc int NOT NULL DEFAULT 0,
  overdue_actions int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN readiness_snapshots.id IS 'Primary key';
COMMENT ON COLUMN readiness_snapshots.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE readiness_snapshots IS 'Computed certification readiness per edition, kept as history.';
-- Certificates obtained by the client.
CREATE TABLE certificates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  edition_id uuid NOT NULL,
  certification_body_id uuid,
  number text,
  scope text,
  issued_on date,
  expires_on date,
  status certificate_status NOT NULL DEFAULT 'valid',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN certificates.id IS 'Primary key';
COMMENT ON COLUMN certificates.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE certificates IS 'Certificates obtained by the client.';

-- ================================================================== Context, scope & leadership
-- The client's (integrated) management system: scope and boundaries (4.3).
CREATE TABLE management_systems (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  name text NOT NULL,
  scope_statement text,
  boundaries text,
  document_id uuid,
  approved_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN management_systems.id IS 'Primary key';
COMMENT ON COLUMN management_systems.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE management_systems IS 'The client''s (integrated) management system: scope and boundaries (4.3).';
-- Standards the system covers.
CREATE TABLE management_system_editions (
  organization_id uuid NOT NULL,
  management_system_id uuid NOT NULL,
  edition_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (management_system_id, edition_id)
);
COMMENT ON COLUMN management_system_editions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE management_system_editions IS 'Standards the system covers.';
-- Non-applicable requirements with justification.
CREATE TABLE clause_exclusions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  management_system_id uuid NOT NULL,
  clause_id uuid NOT NULL,
  justification text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (management_system_id, clause_id)
);
COMMENT ON COLUMN clause_exclusions.id IS 'Primary key';
COMMENT ON COLUMN clause_exclusions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE clause_exclusions IS 'Non-applicable requirements with justification.';
-- Internal/external issues, SWOT (MAN-QSE-001).
CREATE TABLE context_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  nature issue_nature NOT NULL,
  swot_type swot_type,
  category text,
  title text NOT NULL,
  description text,
  impact text,
  systems qse_system[] NOT NULL DEFAULT '{}',
  process_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  reviewed_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN context_issues.id IS 'Primary key';
COMMENT ON COLUMN context_issues.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN context_issues.category IS 'PESTEL / 5M bucket';
COMMENT ON TABLE context_issues IS 'Internal/external issues, SWOT (MAN-QSE-001).';
-- Relevant interested parties (PIP).
CREATE TABLE interested_parties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  name text NOT NULL,
  category text,
  nature issue_nature NOT NULL,
  influence int,
  interest int,
  is_relevant boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN interested_parties.id IS 'Primary key';
COMMENT ON COLUMN interested_parties.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN interested_parties.influence IS '1..3';
COMMENT ON COLUMN interested_parties.interest IS '1..3';
COMMENT ON TABLE interested_parties IS 'Relevant interested parties (PIP).';
-- Needs & expectations; flagged ones become compliance obligations.
CREATE TABLE party_requirements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  party_id uuid NOT NULL,
  requirement text NOT NULL,
  is_compliance_obligation boolean NOT NULL DEFAULT false,
  how_addressed text,
  process_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN party_requirements.id IS 'Primary key';
COMMENT ON COLUMN party_requirements.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE party_requirements IS 'Needs & expectations; flagged ones become compliance obligations.';
-- Strategic axes of the QSE policy that objectives hang from.
CREATE TABLE policy_axes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  policy_document_id uuid,
  code text,
  title text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN policy_axes.id IS 'Primary key';
COMMENT ON COLUMN policy_axes.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE policy_axes IS 'Strategic axes of the QSE policy that objectives hang from.';

-- ================================================================== Processes
-- Process map entries with the full process sheet header.
CREATE TABLE processes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  type process_type NOT NULL,
  parent_id uuid,
  owner_membership_id uuid,
  deputy_membership_id uuid,
  purpose text,
  scope text,
  start_trigger text,
  end_output text,
  human_resources text,
  material_resources text,
  monitoring_methods text,
  sheet_document_id uuid,
  template_id uuid,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, code)
);
COMMENT ON COLUMN processes.id IS 'Primary key';
COMMENT ON COLUMN processes.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN processes.code IS 'e.g. PCS-QSE';
COMMENT ON COLUMN processes.owner_membership_id IS 'Pilote';
COMMENT ON COLUMN processes.purpose IS 'Finalité';
COMMENT ON TABLE processes IS 'Process map entries with the full process sheet header.';
-- Déroulement: inputs → activity → responsible → outputs.
CREATE TABLE process_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  process_id uuid NOT NULL,
  step_no int NOT NULL,
  inputs text,
  activity text NOT NULL,
  responsible_position_id uuid,
  responsible_text text,
  interactions text,
  outputs text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (process_id, step_no)
);
COMMENT ON COLUMN process_steps.id IS 'Primary key';
COMMENT ON COLUMN process_steps.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE process_steps IS 'Déroulement: inputs → activity → responsible → outputs.';
-- Documents associated with a step.
CREATE TABLE process_step_documents (
  organization_id uuid NOT NULL,
  step_id uuid NOT NULL,
  document_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (step_id, document_id)
);
COMMENT ON COLUMN process_step_documents.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE process_step_documents IS 'Documents associated with a step.';
-- Flows between processes (cartographie).
CREATE TABLE process_interactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  from_process_id uuid NOT NULL,
  to_process_id uuid NOT NULL,
  flow text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN process_interactions.id IS 'Primary key';
COMMENT ON COLUMN process_interactions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE process_interactions IS 'Flows between processes (cartographie).';
-- Clauses each process covers.
CREATE TABLE process_clauses (
  organization_id uuid NOT NULL,
  process_id uuid NOT NULL,
  clause_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (process_id, clause_id)
);
COMMENT ON COLUMN process_clauses.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE process_clauses IS 'Clauses each process covers.';
-- Periodic process performance review (tableau de bord PCS).
CREATE TABLE process_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  process_id uuid NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  reviewer_membership_id uuid,
  summary text,
  conclusion review_conclusion,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN process_reviews.id IS 'Primary key';
COMMENT ON COLUMN process_reviews.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE process_reviews IS 'Periodic process performance review (tableau de bord PCS).';

-- ================================================================== Documented information & registers
-- Per-client coding prefixes (PLT, PCS, PRO, INT, MAN, PLN, LST, ID, DOC).
CREATE TABLE document_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  code text NOT NULL,
  label text NOT NULL,
  category doc_category NOT NULL,
  requires_approval boolean NOT NULL DEFAULT true,
  default_review_months int,
  retention_months int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, code)
);
COMMENT ON COLUMN document_types.id IS 'Primary key';
COMMENT ON COLUMN document_types.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE document_types IS 'Per-client coding prefixes (PLT, PCS, PRO, INT, MAN, PLN, LST, ID, DOC).';
-- Master list of documented information (ID-QSE-015).
CREATE TABLE documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  code text NOT NULL,
  title text NOT NULL,
  document_type_id uuid NOT NULL,
  process_id uuid,
  owner_membership_id uuid,
  status doc_status NOT NULL DEFAULT 'draft',
  current_version_id uuid,
  confidentiality confidentiality NOT NULL DEFAULT 'internal',
  review_months int,
  next_review_on date,
  retention_months int,
  source doc_source NOT NULL DEFAULT 'created',
  external_origin text,
  template_id uuid,
  template_version int,
  legacy_path text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, code)
);
COMMENT ON COLUMN documents.id IS 'Primary key';
COMMENT ON COLUMN documents.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN documents.external_origin IS 'For external documents';
COMMENT ON COLUMN documents.template_version IS 'Template version it was copied from';
COMMENT ON COLUMN documents.legacy_path IS 'Where it lived before import';
COMMENT ON TABLE documents IS 'Master list of documented information (ID-QSE-015).';
-- Revisions with content/file and change history.
CREATE TABLE document_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  document_id uuid NOT NULL,
  revision text NOT NULL,
  version_no int NOT NULL,
  change_summary text,
  content jsonb,
  file_id uuid,
  status version_status NOT NULL DEFAULT 'draft',
  effective_on date,
  superseded_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (document_id, version_no)
);
COMMENT ON COLUMN document_versions.id IS 'Primary key';
COMMENT ON COLUMN document_versions.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN document_versions.revision IS 'e.g. 00, 01';
COMMENT ON COLUMN document_versions.change_summary IS 'Objet de la modification';
COMMENT ON TABLE document_versions IS 'Revisions with content/file and change history.';
-- Rédacteur / vérificateur / approbateur circuit with e-signature.
CREATE TABLE document_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  version_id uuid NOT NULL,
  step approval_step NOT NULL,
  assignee_membership_id uuid,
  assignee_firm_member_id uuid,
  decision approval_decision NOT NULL DEFAULT 'pending',
  comment text,
  decided_at timestamptz,
  signature_hash text,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN document_approvals.id IS 'Primary key';
COMMENT ON COLUMN document_approvals.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE document_approvals IS 'Rédacteur / vérificateur / approbateur circuit with e-signature.';
-- Points de diffusion.
CREATE TABLE distribution_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text NOT NULL,
  location text NOT NULL,
  functions text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN distribution_points.id IS 'Primary key';
COMMENT ON COLUMN distribution_points.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE distribution_points IS 'Points de diffusion.';
-- Where each version is distributed, for application or information.
CREATE TABLE document_distributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  version_id uuid NOT NULL,
  distribution_point_id uuid NOT NULL,
  purpose distribution_purpose NOT NULL DEFAULT 'application',
  distributed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN document_distributions.id IS 'Primary key';
COMMENT ON COLUMN document_distributions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE document_distributions IS 'Where each version is distributed, for application or information.';
-- Read-and-understood confirmations.
CREATE TABLE document_acknowledgements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  version_id uuid NOT NULL,
  membership_id uuid,
  employee_id uuid,
  acknowledged_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN document_acknowledgements.id IS 'Primary key';
COMMENT ON COLUMN document_acknowledgements.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE document_acknowledgements IS 'Read-and-understood confirmations.';
-- Clauses a document satisfies (feeds readiness).
CREATE TABLE document_clauses (
  organization_id uuid NOT NULL,
  document_id uuid NOT NULL,
  clause_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (document_id, clause_id)
);
COMMENT ON COLUMN document_clauses.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE document_clauses IS 'Clauses a document satisfies (feeds readiness).';
-- Counters for automatic codes (PRO-QSE-007 → next is 008).
CREATE TABLE document_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  document_type_id uuid NOT NULL,
  process_id uuid,
  last_value int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE NULLS NOT DISTINCT (organization_id, document_type_id, process_id)
);
COMMENT ON COLUMN document_sequences.id IS 'Primary key';
COMMENT ON COLUMN document_sequences.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE document_sequences IS 'Counters for automatic codes (PRO-QSE-007 → next is 008).';
-- Configurable registers/forms for the long tail (fiche d'intervention, PV de réunion…).
CREATE TABLE register_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_id uuid NOT NULL,
  org_id uuid,
  code text,
  name text NOT NULL,
  description text,
  schema jsonb NOT NULL,
  document_id uuid,
  process_id uuid,
  numbering_pattern text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid
);
COMMENT ON COLUMN register_definitions.id IS 'Primary key';
COMMENT ON COLUMN register_definitions.org_id IS 'NULL = firm template';
COMMENT ON COLUMN register_definitions.schema IS 'Field definitions (JSON Schema)';
COMMENT ON COLUMN register_definitions.document_id IS 'Controlled form it implements';
COMMENT ON TABLE register_definitions IS 'Configurable registers/forms for the long tail (fiche d''intervention, PV de réunion…).';
-- Rows/records of a configurable register.
CREATE TABLE register_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  definition_id uuid NOT NULL,
  number text,
  data jsonb NOT NULL,
  site_id uuid,
  process_id uuid,
  project_id uuid,
  recorded_on date NOT NULL DEFAULT CURRENT_DATE,
  status text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN register_entries.id IS 'Primary key';
COMMENT ON COLUMN register_entries.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE register_entries IS 'Rows/records of a configurable register.';
-- Management of change (ID-QSE-020 / PRO-QSE-005).
CREATE TABLE change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text NOT NULL,
  title text NOT NULL,
  type change_type NOT NULL,
  description text,
  reason text,
  risk_assessment text,
  requested_by uuid,
  approved_by uuid,
  status change_status NOT NULL DEFAULT 'requested',
  planned_on date,
  implemented_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, number)
);
COMMENT ON COLUMN change_requests.id IS 'Primary key';
COMMENT ON COLUMN change_requests.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE change_requests IS 'Management of change (ID-QSE-020 / PRO-QSE-005).';
-- Records impacted by a change (documents, processes, risks…).
CREATE TABLE change_impacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  change_request_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN change_impacts.id IS 'Primary key';
COMMENT ON COLUMN change_impacts.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE change_impacts IS 'Records impacted by a change (documents, processes, risks…).';
-- Organizational knowledge register (7.1.6).
CREATE TABLE knowledge_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  process_id uuid,
  domain text,
  title text NOT NULL,
  description text,
  holder_employee_id uuid,
  source direction,
  capture_method text,
  document_id uuid,
  is_critical boolean NOT NULL DEFAULT false,
  sharing_method text,
  reviewed_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN knowledge_items.id IS 'Primary key';
COMMENT ON COLUMN knowledge_items.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE knowledge_items IS 'Organizational knowledge register (7.1.6).';

-- ================================================================== Risks, hazards, aspects & emergencies
-- Units of analysis: Administration, Chantier électricité, Routier…
CREATE TABLE activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  process_id uuid,
  name text NOT NULL,
  type activity_type NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN activities.id IS 'Primary key';
COMMENT ON COLUMN activities.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE activities IS 'Units of analysis: Administration, Chantier électricité, Routier…';
-- A risk / OHS / environmental manual (MAN-QSE-002/003/004).
CREATE TABLE risk_assessments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  kind assessment_kind NOT NULL,
  scoring_model_id uuid NOT NULL,
  title text NOT NULL,
  document_id uuid,
  year int,
  status plan_status NOT NULL DEFAULT 'draft',
  reviewed_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN risk_assessments.id IS 'Primary key';
COMMENT ON COLUMN risk_assessments.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE risk_assessments IS 'A risk / OHS / environmental manual (MAN-QSE-002/003/004).';
-- One risk, opportunity, OHS hazard or environmental aspect.
CREATE TABLE risk_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  assessment_id uuid NOT NULL,
  kind risk_kind NOT NULL,
  reference text,
  activity_id uuid,
  process_id uuid,
  context_issue_id uuid,
  interested_party_id uuid,
  title text NOT NULL,
  cause_category cause_category,
  cause text,
  consequence text,
  existing_controls text,
  owner_membership_id uuid,
  current_score numeric(8,2),
  current_band_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  template_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN risk_items.id IS 'Primary key';
COMMENT ON COLUMN risk_items.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN risk_items.current_score IS 'Denormalized latest';
COMMENT ON TABLE risk_items IS 'One risk, opportunity, OHS hazard or environmental aspect.';
-- OHS-specific fields (ISO 45001 6.1.2).
CREATE TABLE ohs_hazard_details (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  risk_item_id uuid NOT NULL UNIQUE,
  task text,
  hazard_family text,
  routine routine_type NOT NULL DEFAULT 'routine',
  exposed_persons text,
  exposed_count int,
  regulatory_requirement_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN ohs_hazard_details.id IS 'Primary key';
COMMENT ON COLUMN ohs_hazard_details.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE ohs_hazard_details IS 'OHS-specific fields (ISO 45001 6.1.2).';
-- Environmental fields (ISO 14001 6.1.2) incl. life-cycle perspective.
CREATE TABLE env_aspect_details (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  risk_item_id uuid NOT NULL UNIQUE,
  aspect text NOT NULL,
  impact text NOT NULL,
  operating_condition env_condition NOT NULL DEFAULT 'normal',
  lifecycle_stage lifecycle_stage,
  control_level control_level NOT NULL DEFAULT 'control',
  is_significant boolean NOT NULL DEFAULT false,
  significance_reason text,
  regulatory_requirement_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN env_aspect_details.id IS 'Primary key';
COMMENT ON COLUMN env_aspect_details.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE env_aspect_details IS 'Environmental fields (ISO 14001 6.1.2) incl. life-cycle perspective.';
-- Initial / residual / re-evaluation with score, band, mastery, efficacy.
CREATE TABLE risk_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  risk_item_id uuid NOT NULL,
  phase eval_phase NOT NULL,
  evaluated_on date NOT NULL,
  evaluator_membership_id uuid,
  score numeric(8,2) NOT NULL,
  band_id uuid,
  mastery_level numeric(4,2),
  efficacy numeric(3,2),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN risk_evaluations.id IS 'Primary key';
COMMENT ON COLUMN risk_evaluations.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN risk_evaluations.efficacy IS '0 / 0.5 / 1';
COMMENT ON TABLE risk_evaluations IS 'Initial / residual / re-evaluation with score, band, mastery, efficacy.';
-- Value per dimension (G=3, P=2, D=4).
CREATE TABLE risk_evaluation_scores (
  organization_id uuid NOT NULL,
  evaluation_id uuid NOT NULL,
  dimension_id uuid NOT NULL,
  value numeric(6,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (evaluation_id, dimension_id)
);
COMMENT ON COLUMN risk_evaluation_scores.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE risk_evaluation_scores IS 'Value per dimension (G=3, P=2, D=4).';
-- Potential emergencies and response (PLN-QSE-002).
CREATE TABLE emergency_situations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  risk_item_id uuid,
  title text NOT NULL,
  scenario text,
  consequences text,
  response_document_id uuid,
  resources text,
  responsible_membership_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN emergency_situations.id IS 'Primary key';
COMMENT ON COLUMN emergency_situations.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE emergency_situations IS 'Potential emergencies and response (PLN-QSE-002).';
-- Opérations blanches: plan, execution, PV, efficacy.
CREATE TABLE emergency_drills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  emergency_situation_id uuid NOT NULL,
  site_id uuid,
  planned_on date NOT NULL,
  performed_on date,
  participants_count int,
  duration_minutes int,
  observations text,
  efficacy numeric(3,2),
  status session_status NOT NULL DEFAULT 'planned',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN emergency_drills.id IS 'Primary key';
COMMENT ON COLUMN emergency_drills.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE emergency_drills IS 'Opérations blanches: plan, execution, PV, efficacy.';
-- Chemical inventory with SDS and storage class.
CREATE TABLE hazardous_substances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  name text NOT NULL,
  supplier_id uuid,
  usage text,
  hazard_classes text[] NOT NULL DEFAULT '{}',
  sds_file_id uuid,
  sds_revision_on date,
  storage_location text,
  max_quantity numeric(12,3),
  unit text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN hazardous_substances.id IS 'Primary key';
COMMENT ON COLUMN hazardous_substances.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN hazardous_substances.hazard_classes IS 'GHS pictograms';
COMMENT ON TABLE hazardous_substances IS 'Chemical inventory with SDS and storage class.';

-- ================================================================== Compliance obligations
-- Applicable requirements for this client (legal + other).
CREATE TABLE compliance_obligations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  source obligation_source NOT NULL DEFAULT 'legal',
  regulatory_text_id uuid,
  regulatory_requirement_id uuid,
  party_requirement_id uuid,
  title text NOT NULL,
  requirement text,
  system qse_system NOT NULL,
  domain text,
  is_applicable boolean NOT NULL DEFAULT true,
  applicability_note text,
  evaluation_frequency frequency NOT NULL DEFAULT 'annual',
  owner_membership_id uuid,
  process_id uuid,
  risk_if_noncompliant text,
  next_evaluation_on date,
  last_status compliance_status NOT NULL DEFAULT 'not_evaluated',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN compliance_obligations.id IS 'Primary key';
COMMENT ON COLUMN compliance_obligations.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE compliance_obligations IS 'Applicable requirements for this client (legal + other).';
-- Evaluation of compliance (9.1.2 of 14001/45001).
CREATE TABLE compliance_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  obligation_id uuid NOT NULL,
  evaluated_on date NOT NULL,
  status compliance_status NOT NULL,
  evidence text,
  evaluator_membership_id uuid,
  evaluator_firm_member_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN compliance_evaluations.id IS 'Primary key';
COMMENT ON COLUMN compliance_evaluations.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE compliance_evaluations IS 'Evaluation of compliance (9.1.2 of 14001/45001).';

-- ================================================================== Objectives & indicators
-- QSE objectives per policy axis (ID-QSE-002).
CREATE TABLE objectives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  policy_axis_id uuid,
  process_id uuid,
  year int NOT NULL,
  code text,
  title text NOT NULL,
  description text,
  owner_membership_id uuid,
  resources text,
  due_on date,
  completion_level numeric(3,2),
  efficacy numeric(3,2),
  status objective_status NOT NULL DEFAULT 'planned',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN objectives.id IS 'Primary key';
COMMENT ON COLUMN objectives.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN objectives.completion_level IS '0 / 0.5 / 1';
COMMENT ON TABLE objectives IS 'QSE objectives per policy axis (ID-QSE-002).';
-- KPIs per process, optionally tied to an objective.
CREATE TABLE indicators (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  process_id uuid,
  objective_id uuid,
  code text,
  name text NOT NULL,
  definition text,
  formula text,
  unit text,
  comparator comparator NOT NULL DEFAULT 'gte',
  target_value numeric(14,4),
  target_value_max numeric(14,4),
  frequency frequency NOT NULL DEFAULT 'monthly',
  owner_membership_id uuid,
  data_source text,
  template_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN indicators.id IS 'Primary key';
COMMENT ON COLUMN indicators.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE indicators IS 'KPIs per process, optionally tied to an objective.';
-- Period values with analysis (fiche suivi indicateur).
CREATE TABLE indicator_measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  indicator_id uuid NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  value numeric(14,4),
  numerator numeric(14,4),
  denominator numeric(14,4),
  target_snapshot numeric(14,4),
  is_met boolean,
  analysis text,
  entered_by_membership_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (indicator_id, period_start)
);
COMMENT ON COLUMN indicator_measurements.id IS 'Primary key';
COMMENT ON COLUMN indicator_measurements.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE indicator_measurements IS 'Period values with analysis (fiche suivi indicateur).';

-- ================================================================== Nonconformities, actions, incidents & complaints
-- Client's customers (for complaints and satisfaction).
CREATE TABLE customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  name text NOT NULL,
  type text,
  contact text,
  city text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN customers.id IS 'Primary key';
COMMENT ON COLUMN customers.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE customers IS 'Client''s customers (for complaints and satisfaction).';

-- ================================================================== Operations: suppliers, equipment, inspections, environment
-- Worksites / projects / contracts (chantiers).
CREATE TABLE projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  customer_id uuid,
  site_id uuid,
  code text,
  name text NOT NULL,
  type text,
  starts_on date,
  ends_on date,
  status project_status NOT NULL DEFAULT 'planned',
  manager_membership_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN projects.id IS 'Primary key';
COMMENT ON COLUMN projects.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE projects IS 'Worksites / projects / contracts (chantiers).';

-- ================================================================== Nonconformities, actions, incidents & complaints
-- Customer satisfaction measurements (9.1.2).
CREATE TABLE customer_surveys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  customer_id uuid,
  project_id uuid,
  sent_on date,
  answered_on date,
  score numeric(5,2),
  responses jsonb,
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN customer_surveys.id IS 'Primary key';
COMMENT ON COLUMN customer_surveys.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE customer_surveys IS 'Customer satisfaction measurements (9.1.2).';
-- Customer complaints (réclamations).
CREATE TABLE complaints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text NOT NULL,
  customer_id uuid,
  project_id uuid,
  received_on date NOT NULL,
  channel text,
  description text NOT NULL,
  is_justified boolean,
  response text,
  responded_on date,
  status complaint_status NOT NULL DEFAULT 'received',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, number)
);
COMMENT ON COLUMN complaints.id IS 'Primary key';
COMMENT ON COLUMN complaints.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE complaints IS 'Customer complaints (réclamations).';
-- Work accidents, near-misses, environmental incidents.
CREATE TABLE incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text NOT NULL,
  type incident_type NOT NULL,
  site_id uuid,
  project_id uuid,
  occurred_at timestamptz NOT NULL,
  location text,
  description text NOT NULL,
  employee_id uuid,
  injury_nature text,
  lost_days int,
  severity int,
  immediate_actions text,
  reported_by_membership_id uuid,
  authority_declared_on date,
  investigation text,
  status incident_status NOT NULL DEFAULT 'reported',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, number)
);
COMMENT ON COLUMN incidents.id IS 'Primary key';
COMMENT ON COLUMN incidents.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN incidents.employee_id IS 'Person involved (restricted access)';
COMMENT ON COLUMN incidents.severity IS '1..4';
COMMENT ON TABLE incidents IS 'Work accidents, near-misses, environmental incidents.';
-- Single NC register for every origin (ID-QSE-012, all tabs).
CREATE TABLE nonconformities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text NOT NULL,
  title text NOT NULL,
  description text,
  detected_on date NOT NULL,
  source nc_source NOT NULL,
  severity nc_severity NOT NULL DEFAULT 'minor',
  process_id uuid,
  site_id uuid,
  project_id uuid,
  supplier_id uuid,
  detected_by_membership_id uuid,
  detected_by_firm_member_id uuid,
  owner_membership_id uuid,
  containment text,
  rca_method rca_method,
  rca jsonb,
  root_cause text,
  status nc_status NOT NULL DEFAULT 'open',
  closed_on date,
  efficacy numeric(3,2),
  efficacy_verified_on date,
  audit_finding_id uuid,
  gap_assessment_item_id uuid,
  indicator_measurement_id uuid,
  complaint_id uuid,
  incident_id uuid,
  emergency_drill_id uuid,
  compliance_evaluation_id uuid,
  inspection_result_id uuid,
  management_review_id uuid,
  worker_meeting_id uuid,
  register_entry_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, number),
  CHECK (num_nonnulls(audit_finding_id, gap_assessment_item_id, indicator_measurement_id, complaint_id, incident_id, emergency_drill_id, compliance_evaluation_id, inspection_result_id, management_review_id, worker_meeting_id, register_entry_id) <= 1)
);
COMMENT ON COLUMN nonconformities.id IS 'Primary key';
COMMENT ON COLUMN nonconformities.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN nonconformities.containment IS 'Immediate correction';
COMMENT ON COLUMN nonconformities.rca IS '5 whys / Ishikawa content';
COMMENT ON TABLE nonconformities IS 'Single NC register for every origin (ID-QSE-012, all tabs).';
-- Clauses concerned by an NC.
CREATE TABLE nonconformity_clauses (
  organization_id uuid NOT NULL,
  nonconformity_id uuid NOT NULL,
  clause_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (nonconformity_id, clause_id)
);
COMMENT ON COLUMN nonconformity_clauses.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE nonconformity_clauses IS 'Clauses concerned by an NC.';
-- THE action plan: every correction, corrective action, risk treatment, objective action…
CREATE TABLE actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text NOT NULL,
  title text NOT NULL,
  description text,
  type action_type NOT NULL,
  source action_source NOT NULL DEFAULT 'standalone',
  priority priority NOT NULL DEFAULT 'medium',
  status action_status NOT NULL DEFAULT 'planned',
  due_on date,
  completed_on date,
  completion_level numeric(3,2) NOT NULL DEFAULT 0,
  resources text,
  cost numeric(12,2),
  efficacy_criteria text,
  efficacy_due_on date,
  efficacy numeric(3,2),
  efficacy_verified_by uuid,
  efficacy_verified_on date,
  nonconformity_id uuid,
  risk_item_id uuid,
  objective_id uuid,
  audit_finding_id uuid,
  management_review_decision_id uuid,
  gap_assessment_item_id uuid,
  compliance_evaluation_id uuid,
  change_request_id uuid,
  worker_meeting_id uuid,
  emergency_drill_id uuid,
  equipment_check_id uuid,
  inspection_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, number),
  CHECK (num_nonnulls(nonconformity_id, risk_item_id, objective_id, audit_finding_id, management_review_decision_id, gap_assessment_item_id, compliance_evaluation_id, change_request_id, worker_meeting_id, emergency_drill_id, equipment_check_id, inspection_id) <= 1)
);
COMMENT ON COLUMN actions.id IS 'Primary key';
COMMENT ON COLUMN actions.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN actions.completion_level IS '0 / 0.5 / 1';
COMMENT ON TABLE actions IS 'THE action plan: every correction, corrective action, risk treatment, objective action…';
-- Several owners per action ("R QSE + D technique").
CREATE TABLE action_owners (
  organization_id uuid NOT NULL,
  action_id uuid NOT NULL,
  membership_id uuid NOT NULL,
  is_lead boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (action_id, membership_id)
);
COMMENT ON COLUMN action_owners.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE action_owners IS 'Several owners per action ("R QSE + D technique").';
-- Progress log on an action.
CREATE TABLE action_updates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  action_id uuid NOT NULL,
  note text NOT NULL,
  completion_level numeric(3,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN action_updates.id IS 'Primary key';
COMMENT ON COLUMN action_updates.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE action_updates IS 'Progress log on an action.';

-- ================================================================== Audits
-- Annual internal audit programme (ID-QSE-017).
CREATE TABLE audit_programs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  year int NOT NULL,
  title text,
  document_id uuid,
  criteria text,
  status plan_status NOT NULL DEFAULT 'draft',
  approved_by uuid,
  approved_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, year)
);
COMMENT ON COLUMN audit_programs.id IS 'Primary key';
COMMENT ON COLUMN audit_programs.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE audit_programs IS 'Annual internal audit programme (ID-QSE-017).';
-- Planned audits per process and period.
CREATE TABLE audit_program_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  program_id uuid NOT NULL,
  process_id uuid,
  clause_refs text,
  planned_month int,
  planned_week int,
  audit_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN audit_program_items.id IS 'Primary key';
COMMENT ON COLUMN audit_program_items.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN audit_program_items.planned_month IS '1..12';
COMMENT ON COLUMN audit_program_items.planned_week IS '1..5';
COMMENT ON COLUMN audit_program_items.audit_id IS 'Audit that realised it';
COMMENT ON TABLE audit_program_items IS 'Planned audits per process and period.';
-- Any audit: internal, mock, supplier, certification stages.
CREATE TABLE audits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  type audit_type NOT NULL,
  title text NOT NULL,
  objectives text,
  scope text,
  criteria text,
  supplier_id uuid,
  certification_body_id uuid,
  engagement_id uuid,
  planned_start date,
  planned_end date,
  actual_start date,
  actual_end date,
  status audit_status NOT NULL DEFAULT 'planned',
  conclusion text,
  certification_recommended boolean,
  report_document_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN audits.id IS 'Primary key';
COMMENT ON COLUMN audits.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE audits IS 'Any audit: internal, mock, supplier, certification stages.';
-- Standards audited.
CREATE TABLE audit_editions (
  organization_id uuid NOT NULL,
  audit_id uuid NOT NULL,
  edition_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (audit_id, edition_id)
);
COMMENT ON COLUMN audit_editions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE audit_editions IS 'Standards audited.';
-- Auditors: client staff, consultants or external auditors.
CREATE TABLE audit_team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  audit_id uuid NOT NULL,
  role audit_role NOT NULL,
  membership_id uuid,
  firm_member_id uuid,
  external_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  CHECK (num_nonnulls(membership_id, firm_member_id, external_name) = 1)
);
COMMENT ON COLUMN audit_team_members.id IS 'Primary key';
COMMENT ON COLUMN audit_team_members.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE audit_team_members IS 'Auditors: client staff, consultants or external auditors.';
-- Audit plan: time slots per process/site/clauses.
CREATE TABLE audit_plan_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  audit_id uuid NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  process_id uuid,
  site_id uuid,
  clause_refs text,
  auditees text,
  team_member_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN audit_plan_slots.id IS 'Primary key';
COMMENT ON COLUMN audit_plan_slots.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE audit_plan_slots IS 'Audit plan: time slots per process/site/clauses.';
-- Questions, evidence and result per clause.
CREATE TABLE audit_checklist_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  audit_id uuid NOT NULL,
  clause_id uuid,
  process_id uuid,
  question text NOT NULL,
  result checklist_result,
  evidence text,
  notes text,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN audit_checklist_items.id IS 'Primary key';
COMMENT ON COLUMN audit_checklist_items.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE audit_checklist_items IS 'Questions, evidence and result per clause.';
-- Findings; NCs are raised from them.
CREATE TABLE audit_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  audit_id uuid NOT NULL,
  number text,
  type finding_type NOT NULL,
  clause_id uuid,
  process_id uuid,
  site_id uuid,
  requirement text,
  description text NOT NULL,
  evidence text,
  status finding_status NOT NULL DEFAULT 'open',
  response_due_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN audit_findings.id IS 'Primary key';
COMMENT ON COLUMN audit_findings.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE audit_findings IS 'Findings; NCs are raised from them.';

-- ================================================================== Management review
-- Revue de direction.
CREATE TABLE management_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text,
  planned_on date,
  held_on date,
  period_start date,
  period_end date,
  status review_status NOT NULL DEFAULT 'planned',
  chair_membership_id uuid,
  minutes_document_id uuid,
  next_review_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN management_reviews.id IS 'Primary key';
COMMENT ON COLUMN management_reviews.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE management_reviews IS 'Revue de direction.';
-- Attendees.
CREATE TABLE management_review_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  review_id uuid NOT NULL,
  membership_id uuid,
  firm_member_id uuid,
  external_name text,
  role text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN management_review_participants.id IS 'Primary key';
COMMENT ON COLUMN management_review_participants.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE management_review_participants IS 'Attendees.';
-- Mandatory inputs, auto-compiled from the other modules as snapshots.
CREATE TABLE management_review_inputs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  review_id uuid NOT NULL,
  input_type mr_input NOT NULL,
  summary text,
  data_snapshot jsonb,
  prepared_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (review_id, input_type)
);
COMMENT ON COLUMN management_review_inputs.id IS 'Primary key';
COMMENT ON COLUMN management_review_inputs.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN management_review_inputs.data_snapshot IS 'Frozen figures at review time';
COMMENT ON TABLE management_review_inputs IS 'Mandatory inputs, auto-compiled from the other modules as snapshots.';
-- Outputs: decisions that become actions.
CREATE TABLE management_review_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  review_id uuid NOT NULL,
  output_type mr_output NOT NULL,
  description text NOT NULL,
  owner_membership_id uuid,
  due_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN management_review_decisions.id IS 'Primary key';
COMMENT ON COLUMN management_review_decisions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE management_review_decisions IS 'Outputs: decisions that become actions.';

-- ================================================================== People: competence, training, participation
-- Job positions / fiches fonction; reports_to builds the organigram.
CREATE TABLE positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  code text,
  title text NOT NULL,
  process_id uuid,
  reports_to_id uuid,
  mission text,
  responsibilities text,
  qse_responsibilities text,
  authorities text,
  document_id uuid,
  headcount int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN positions.id IS 'Primary key';
COMMENT ON COLUMN positions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE positions IS 'Job positions / fiches fonction; reports_to builds the organigram.';
-- Staff (not all are platform users). Minimal personal data.
CREATE TABLE employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  membership_id uuid UNIQUE,
  position_id uuid,
  site_id uuid,
  employee_number text,
  full_name text NOT NULL,
  hire_date date,
  end_date date,
  contract_type contract_type,
  status employee_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN employees.id IS 'Primary key';
COMMENT ON COLUMN employees.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE employees IS 'Staff (not all are platform users). Minimal personal data.';
-- Competency catalogue incl. authorizations (habilitation électrique).
CREATE TABLE competencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  name text NOT NULL,
  category competency_category NOT NULL,
  requires_certificate boolean NOT NULL DEFAULT false,
  validity_months int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN competencies.id IS 'Primary key';
COMMENT ON COLUMN competencies.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE competencies IS 'Competency catalogue incl. authorizations (habilitation électrique).';
-- Required competencies per position.
CREATE TABLE position_competencies (
  organization_id uuid NOT NULL,
  position_id uuid NOT NULL,
  competency_id uuid NOT NULL,
  required_level int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (position_id, competency_id)
);
COMMENT ON COLUMN position_competencies.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE position_competencies IS 'Required competencies per position.';
-- Competency assessments (cadre / chantier grids).
CREATE TABLE competency_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  competency_id uuid NOT NULL,
  evaluated_on date NOT NULL,
  level int NOT NULL,
  evaluator_membership_id uuid,
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN competency_evaluations.id IS 'Primary key';
COMMENT ON COLUMN competency_evaluations.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE competency_evaluations IS 'Competency assessments (cadre / chantier grids).';
-- Certificates/authorizations with expiry.
CREATE TABLE employee_qualifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  competency_id uuid NOT NULL,
  reference text,
  issued_on date,
  expires_on date,
  issuer_supplier_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN employee_qualifications.id IS 'Primary key';
COMMENT ON COLUMN employee_qualifications.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE employee_qualifications IS 'Certificates/authorizations with expiry.';
-- Identified training needs.
CREATE TABLE training_needs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  employee_id uuid,
  position_id uuid,
  competency_id uuid,
  title text NOT NULL,
  source need_source NOT NULL,
  priority priority NOT NULL DEFAULT 'medium',
  year int NOT NULL,
  status request_status NOT NULL DEFAULT 'submitted',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN training_needs.id IS 'Primary key';
COMMENT ON COLUMN training_needs.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE training_needs IS 'Identified training needs.';
-- Annual training & awareness programme.
CREATE TABLE training_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  year int NOT NULL,
  status plan_status NOT NULL DEFAULT 'draft',
  document_id uuid,
  budget numeric(12,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id),
  UNIQUE (organization_id, year)
);
COMMENT ON COLUMN training_plans.id IS 'Primary key';
COMMENT ON COLUMN training_plans.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE training_plans IS 'Annual training & awareness programme.';
-- Trainings, awareness sessions, inductions, toolbox talks.
CREATE TABLE training_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  plan_id uuid,
  need_id uuid,
  kind session_kind NOT NULL,
  title text NOT NULL,
  competency_id uuid,
  provider_supplier_id uuid,
  trainer text,
  site_id uuid,
  planned_start date,
  planned_end date,
  performed_on date,
  duration_hours numeric(6,2),
  cost numeric(12,2),
  status session_status NOT NULL DEFAULT 'planned',
  efficacy numeric(3,2),
  evaluation_summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN training_sessions.id IS 'Primary key';
COMMENT ON COLUMN training_sessions.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE training_sessions IS 'Trainings, awareness sessions, inductions, toolbox talks.';
-- Attendance sheet, signatures and evaluations.
CREATE TABLE training_attendances (
  organization_id uuid NOT NULL,
  session_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  attended boolean NOT NULL DEFAULT false,
  signed boolean NOT NULL DEFAULT false,
  score numeric(5,2),
  hot_evaluation int,
  cold_evaluation int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (session_id, employee_id)
);
COMMENT ON COLUMN training_attendances.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE training_attendances IS 'Attendance sheet, signatures and evaluations.';
-- Recruitment needs.
CREATE TABLE recruitment_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  position_id uuid,
  reason text,
  headcount int NOT NULL DEFAULT 1,
  requested_by uuid,
  requested_on date NOT NULL DEFAULT CURRENT_DATE,
  status request_status NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN recruitment_requests.id IS 'Primary key';
COMMENT ON COLUMN recruitment_requests.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE recruitment_requests IS 'Recruitment needs.';
-- Integration plan for new hires.
CREATE TABLE onboarding_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  tutor_employee_id uuid,
  starts_on date,
  steps jsonb NOT NULL DEFAULT '[]',
  completed_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN onboarding_plans.id IS 'Primary key';
COMMENT ON COLUMN onboarding_plans.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE onboarding_plans IS 'Integration plan for new hires.';
-- Occupational health follow-up: dates and fitness only, never diagnoses.
CREATE TABLE medical_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  visit_type medical_visit_type NOT NULL,
  visit_on date,
  next_due_on date,
  fitness fitness NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN medical_visits.id IS 'Primary key';
COMMENT ON COLUMN medical_visits.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE medical_visits IS 'Occupational health follow-up: dates and fitness only, never diagnoses.';
-- PPE / work clothing issued.
CREATE TABLE ppe_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  item text NOT NULL,
  size text,
  quantity int NOT NULL DEFAULT 1,
  issued_on date NOT NULL,
  renewal_due_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN ppe_issues.id IS 'Primary key';
COMMENT ON COLUMN ppe_issues.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE ppe_issues IS 'PPE / work clothing issued.';
-- Internal/external communication plan (ID-QSE-016).
CREATE TABLE communication_plan_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  subject text NOT NULL,
  direction direction NOT NULL,
  audience text,
  channel text,
  frequency frequency,
  sender_membership_id uuid,
  process_id uuid,
  system qse_system,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN communication_plan_items.id IS 'Primary key';
COMMENT ON COLUMN communication_plan_items.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE communication_plan_items IS 'Internal/external communication plan (ID-QSE-016).';
-- Evidence that a communication happened.
CREATE TABLE communication_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  plan_item_id uuid,
  communicated_on date NOT NULL,
  summary text,
  audience_count int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN communication_records.id IS 'Primary key';
COMMENT ON COLUMN communication_records.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE communication_records IS 'Evidence that a communication happened.';
-- Worker participation & consultation (ISO 45001 5.4).
CREATE TABLE worker_meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  planned_on date,
  held_on date,
  topics text,
  minutes text,
  status session_status NOT NULL DEFAULT 'planned',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN worker_meetings.id IS 'Primary key';
COMMENT ON COLUMN worker_meetings.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE worker_meetings IS 'Worker participation & consultation (ISO 45001 5.4).';
-- Attendees.
CREATE TABLE worker_meeting_participants (
  organization_id uuid NOT NULL,
  meeting_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  role meeting_role NOT NULL DEFAULT 'worker_representative',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (meeting_id, employee_id)
);
COMMENT ON COLUMN worker_meeting_participants.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE worker_meeting_participants IS 'Attendees.';
-- Visitor register with safety briefing.
CREATE TABLE visitor_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  visitor_name text NOT NULL,
  company text,
  purpose text,
  host_employee_id uuid,
  arrived_at timestamptz NOT NULL,
  left_at timestamptz,
  safety_briefing_done boolean NOT NULL DEFAULT false,
  ppe_provided boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN visitor_logs.id IS 'Primary key';
COMMENT ON COLUMN visitor_logs.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE visitor_logs IS 'Visitor register with safety briefing.';

-- ================================================================== Operations: suppliers, equipment, inspections, environment
-- Suppliers and external providers (8.4).
CREATE TABLE suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  name text NOT NULL,
  category supplier_category NOT NULL,
  is_critical boolean NOT NULL DEFAULT false,
  status supplier_decision NOT NULL DEFAULT 'pending',
  contact_name text,
  email text,
  phone text,
  city text,
  approved_on date,
  next_evaluation_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN suppliers.id IS 'Primary key';
COMMENT ON COLUMN suppliers.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE suppliers IS 'Suppliers and external providers (8.4).';
-- Weighted selection/evaluation criteria.
CREATE TABLE supplier_criteria (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  kind evaluation_kind NOT NULL,
  name text NOT NULL,
  weight numeric(5,2) NOT NULL DEFAULT 1,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN supplier_criteria.id IS 'Primary key';
COMMENT ON COLUMN supplier_criteria.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE supplier_criteria IS 'Weighted selection/evaluation criteria.';
-- Selection and periodic evaluations.
CREATE TABLE supplier_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  supplier_id uuid NOT NULL,
  kind evaluation_kind NOT NULL,
  evaluated_on date NOT NULL,
  evaluator_membership_id uuid,
  total_score numeric(6,2),
  decision supplier_decision NOT NULL,
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN supplier_evaluations.id IS 'Primary key';
COMMENT ON COLUMN supplier_evaluations.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE supplier_evaluations IS 'Selection and periodic evaluations.';
-- Score per criterion.
CREATE TABLE supplier_evaluation_scores (
  organization_id uuid NOT NULL,
  evaluation_id uuid NOT NULL,
  criterion_id uuid NOT NULL,
  score numeric(6,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  PRIMARY KEY (evaluation_id, criterion_id)
);
COMMENT ON COLUMN supplier_evaluation_scores.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE supplier_evaluation_scores IS 'Score per criterion.';
-- Measuring instruments, lifting gear, extinguishers, installations, vehicles.
CREATE TABLE equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  category equipment_category NOT NULL,
  code text,
  name text NOT NULL,
  brand text,
  model text,
  serial_number text,
  location text,
  status equipment_status NOT NULL DEFAULT 'in_service',
  commissioned_on date,
  is_regulated boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN equipment.id IS 'Primary key';
COMMENT ON COLUMN equipment.organization_id IS 'Tenant (client organization)';
COMMENT ON COLUMN equipment.is_regulated IS 'Subject to regulatory inspection';
COMMENT ON TABLE equipment IS 'Measuring instruments, lifting gear, extinguishers, installations, vehicles.';
-- Recurring calibration / maintenance / regulatory inspection schedules.
CREATE TABLE equipment_check_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  equipment_id uuid NOT NULL,
  check_type check_type NOT NULL,
  frequency_months int NOT NULL,
  provider_supplier_id uuid,
  next_due_on date,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN equipment_check_plans.id IS 'Primary key';
COMMENT ON COLUMN equipment_check_plans.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE equipment_check_plans IS 'Recurring calibration / maintenance / regulatory inspection schedules.';
-- Performed checks with result and certificate.
CREATE TABLE equipment_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  equipment_id uuid NOT NULL,
  plan_id uuid,
  check_type check_type NOT NULL,
  due_on date,
  performed_on date,
  provider_supplier_id uuid,
  performed_by text,
  result check_result NOT NULL DEFAULT 'pending',
  certificate_ref text,
  cost numeric(12,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN equipment_checks.id IS 'Primary key';
COMMENT ON COLUMN equipment_checks.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE equipment_checks IS 'Performed checks with result and certificate.';
-- Reservations from regulatory inspections (ID-GSM-005).
CREATE TABLE equipment_check_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  check_id uuid NOT NULL,
  description text NOT NULL,
  status reservation_status NOT NULL DEFAULT 'open',
  lifted_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN equipment_check_reservations.id IS 'Primary key';
COMMENT ON COLUMN equipment_check_reservations.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE equipment_check_reservations IS 'Reservations from regulatory inspections (ID-GSM-005).';
-- Inspection/control plans (reception, site quality, HSE).
CREATE TABLE control_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  process_id uuid,
  name text NOT NULL,
  kind control_plan_kind NOT NULL,
  document_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN control_plans.id IS 'Primary key';
COMMENT ON COLUMN control_plans.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE control_plans IS 'Inspection/control plans (reception, site quality, HSE).';
-- What is checked, how, how often, acceptance criteria.
CREATE TABLE control_points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  plan_id uuid NOT NULL,
  characteristic text NOT NULL,
  method text,
  frequency frequency,
  acceptance_criteria text,
  responsible text,
  record_ref text,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN control_points.id IS 'Primary key';
COMMENT ON COLUMN control_points.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE control_points IS 'What is checked, how, how often, acceptance criteria.';
-- An executed inspection (monthly HSE inspection, reception control…).
CREATE TABLE inspections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  number text,
  control_plan_id uuid,
  kind control_plan_kind NOT NULL,
  site_id uuid,
  project_id uuid,
  supplier_id uuid,
  inspected_on date NOT NULL,
  inspector_membership_id uuid,
  status inspection_status NOT NULL DEFAULT 'planned',
  score numeric(5,2),
  summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN inspections.id IS 'Primary key';
COMMENT ON COLUMN inspections.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE inspections IS 'An executed inspection (monthly HSE inspection, reception control…).';
-- Result per point, with photo evidence via attachments.
CREATE TABLE inspection_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  inspection_id uuid NOT NULL,
  control_point_id uuid,
  item text,
  result point_result NOT NULL,
  observation text,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN inspection_results.id IS 'Primary key';
COMMENT ON COLUMN inspection_results.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE inspection_results IS 'Result per point, with photo evidence via attachments.';
-- Waste register.
CREATE TABLE waste_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  waste_type text NOT NULL,
  is_hazardous boolean NOT NULL DEFAULT false,
  quantity numeric(12,3),
  unit text,
  recorded_on date NOT NULL,
  handler_supplier_id uuid,
  disposal_route text,
  manifest_ref text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN waste_records.id IS 'Primary key';
COMMENT ON COLUMN waste_records.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE waste_records IS 'Waste register.';
-- Energy, water, fuel consumption (e.g. monthly fuel per vehicle).
CREATE TABLE consumption_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  equipment_id uuid,
  resource resource_type NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  quantity numeric(14,3) NOT NULL,
  unit text NOT NULL,
  cost numeric(12,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN consumption_records.id IS 'Primary key';
COMMENT ON COLUMN consumption_records.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE consumption_records IS 'Energy, water, fuel consumption (e.g. monthly fuel per vehicle).';
-- Noise, emissions, effluents vs limits.
CREATE TABLE environmental_measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  site_id uuid,
  parameter text NOT NULL,
  measured_on date NOT NULL,
  value numeric(14,4) NOT NULL,
  unit text,
  limit_value numeric(14,4),
  lab_supplier_id uuid,
  is_compliant boolean,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid,
  UNIQUE (organization_id, id)
);
COMMENT ON COLUMN environmental_measurements.id IS 'Primary key';
COMMENT ON COLUMN environmental_measurements.organization_id IS 'Tenant (client organization)';
COMMENT ON TABLE environmental_measurements IS 'Noise, emissions, effluents vs limits.';

-- ================================================================== foreign keys
-- Tenant→tenant references use composite keys (organization_id, x_id) so a row can never
-- point to another client's data, even through a bug in the application layer.
ALTER TABLE firms ADD CONSTRAINT fk_firms_logo_file_id FOREIGN KEY (logo_file_id) REFERENCES files (id) ON DELETE SET NULL;
ALTER TABLE firms ADD CONSTRAINT fk_firms_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE organizations ADD CONSTRAINT fk_organizations_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE organizations ADD CONSTRAINT fk_organizations_sector_id FOREIGN KEY (sector_id) REFERENCES sectors (id) ON DELETE SET NULL;
ALTER TABLE organizations ADD CONSTRAINT fk_organizations_logo_file_id FOREIGN KEY (logo_file_id) REFERENCES files (id) ON DELETE SET NULL;
ALTER TABLE organizations ADD CONSTRAINT fk_organizations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE sites ADD CONSTRAINT fk_sites_parent_site_id FOREIGN KEY (organization_id, parent_site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (parent_site_id);
ALTER TABLE sites ADD CONSTRAINT fk_sites_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE sites ADD CONSTRAINT fk_sites_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE firm_members ADD CONSTRAINT fk_firm_members_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE firm_members ADD CONSTRAINT fk_firm_members_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;
ALTER TABLE firm_members ADD CONSTRAINT fk_firm_members_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE org_memberships ADD CONSTRAINT fk_org_memberships_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;
ALTER TABLE org_memberships ADD CONSTRAINT fk_org_memberships_invited_by FOREIGN KEY (invited_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE org_memberships ADD CONSTRAINT fk_org_memberships_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE org_memberships ADD CONSTRAINT fk_org_memberships_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE roles ADD CONSTRAINT fk_roles_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE roles ADD CONSTRAINT fk_roles_org_id FOREIGN KEY (org_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE roles ADD CONSTRAINT fk_roles_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE role_permissions ADD CONSTRAINT fk_role_permissions_role_id FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE;
ALTER TABLE role_permissions ADD CONSTRAINT fk_role_permissions_permission_id FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE;
ALTER TABLE role_permissions ADD CONSTRAINT fk_role_permissions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE membership_roles ADD CONSTRAINT fk_membership_roles_membership_id FOREIGN KEY (organization_id, membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE CASCADE;
ALTER TABLE membership_roles ADD CONSTRAINT fk_membership_roles_role_id FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE;
ALTER TABLE membership_roles ADD CONSTRAINT fk_membership_roles_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE CASCADE;
ALTER TABLE membership_roles ADD CONSTRAINT fk_membership_roles_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE membership_roles ADD CONSTRAINT fk_membership_roles_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE subscriptions ADD CONSTRAINT fk_subscriptions_engagement_id FOREIGN KEY (organization_id, engagement_id) REFERENCES engagements (organization_id, id) ON DELETE SET NULL (engagement_id);
ALTER TABLE subscriptions ADD CONSTRAINT fk_subscriptions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE subscriptions ADD CONSTRAINT fk_subscriptions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE consultant_assignments ADD CONSTRAINT fk_consultant_assignments_firm_member_id FOREIGN KEY (firm_member_id) REFERENCES firm_members (id) ON DELETE CASCADE;
ALTER TABLE consultant_assignments ADD CONSTRAINT fk_consultant_assignments_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE consultant_assignments ADD CONSTRAINT fk_consultant_assignments_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE invitations ADD CONSTRAINT fk_invitations_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE invitations ADD CONSTRAINT fk_invitations_target_org_id FOREIGN KEY (target_org_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE invitations ADD CONSTRAINT fk_invitations_role_id FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE RESTRICT;
ALTER TABLE invitations ADD CONSTRAINT fk_invitations_invited_by FOREIGN KEY (invited_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE invitations ADD CONSTRAINT fk_invitations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE files ADD CONSTRAINT fk_files_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE files ADD CONSTRAINT fk_files_org_id FOREIGN KEY (org_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE files ADD CONSTRAINT fk_files_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE attachments ADD CONSTRAINT fk_attachments_file_id FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE;
ALTER TABLE attachments ADD CONSTRAINT fk_attachments_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE attachments ADD CONSTRAINT fk_attachments_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE comments ADD CONSTRAINT fk_comments_parent_id FOREIGN KEY (organization_id, parent_id) REFERENCES comments (organization_id, id) ON DELETE CASCADE;
ALTER TABLE comments ADD CONSTRAINT fk_comments_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE comments ADD CONSTRAINT fk_comments_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE notifications ADD CONSTRAINT fk_notifications_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;
ALTER TABLE notifications ADD CONSTRAINT fk_notifications_org_id FOREIGN KEY (org_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE notification_preferences ADD CONSTRAINT fk_notification_preferences_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE;
ALTER TABLE activity_log ADD CONSTRAINT fk_activity_log_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE activity_log ADD CONSTRAINT fk_activity_log_org_id FOREIGN KEY (org_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE activity_log ADD CONSTRAINT fk_activity_log_actor_user_id FOREIGN KEY (actor_user_id) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE import_jobs ADD CONSTRAINT fk_import_jobs_file_id FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE RESTRICT;
ALTER TABLE import_jobs ADD CONSTRAINT fk_import_jobs_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE import_jobs ADD CONSTRAINT fk_import_jobs_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE export_jobs ADD CONSTRAINT fk_export_jobs_document_template_id FOREIGN KEY (document_template_id) REFERENCES document_templates (id) ON DELETE SET NULL;
ALTER TABLE export_jobs ADD CONSTRAINT fk_export_jobs_file_id FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE SET NULL;
ALTER TABLE export_jobs ADD CONSTRAINT fk_export_jobs_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE export_jobs ADD CONSTRAINT fk_export_jobs_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE sectors ADD CONSTRAINT fk_sectors_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE sectors ADD CONSTRAINT fk_sectors_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE standards ADD CONSTRAINT fk_standards_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE standard_editions ADD CONSTRAINT fk_standard_editions_standard_id FOREIGN KEY (standard_id) REFERENCES standards (id) ON DELETE CASCADE;
ALTER TABLE standard_editions ADD CONSTRAINT fk_standard_editions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE clauses ADD CONSTRAINT fk_clauses_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE CASCADE;
ALTER TABLE clauses ADD CONSTRAINT fk_clauses_parent_id FOREIGN KEY (parent_id) REFERENCES clauses (id) ON DELETE CASCADE;
ALTER TABLE clauses ADD CONSTRAINT fk_clauses_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE clause_correspondences ADD CONSTRAINT fk_clause_correspondences_from_clause_id FOREIGN KEY (from_clause_id) REFERENCES clauses (id) ON DELETE CASCADE;
ALTER TABLE clause_correspondences ADD CONSTRAINT fk_clause_correspondences_to_clause_id FOREIGN KEY (to_clause_id) REFERENCES clauses (id) ON DELETE CASCADE;
ALTER TABLE clause_correspondences ADD CONSTRAINT fk_clause_correspondences_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE regulatory_texts ADD CONSTRAINT fk_regulatory_texts_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE regulatory_texts ADD CONSTRAINT fk_regulatory_texts_amended_by_id FOREIGN KEY (amended_by_id) REFERENCES regulatory_texts (id) ON DELETE SET NULL;
ALTER TABLE regulatory_texts ADD CONSTRAINT fk_regulatory_texts_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE regulatory_requirements ADD CONSTRAINT fk_regulatory_requirements_text_id FOREIGN KEY (text_id) REFERENCES regulatory_texts (id) ON DELETE CASCADE;
ALTER TABLE regulatory_requirements ADD CONSTRAINT fk_regulatory_requirements_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE substance_compatibility_rules ADD CONSTRAINT fk_substance_compatibility_rules_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE scoring_models ADD CONSTRAINT fk_scoring_models_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE scoring_models ADD CONSTRAINT fk_scoring_models_org_id FOREIGN KEY (org_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE scoring_models ADD CONSTRAINT fk_scoring_models_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE scoring_dimensions ADD CONSTRAINT fk_scoring_dimensions_model_id FOREIGN KEY (model_id) REFERENCES scoring_models (id) ON DELETE CASCADE;
ALTER TABLE scoring_dimensions ADD CONSTRAINT fk_scoring_dimensions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE scoring_levels ADD CONSTRAINT fk_scoring_levels_dimension_id FOREIGN KEY (dimension_id) REFERENCES scoring_dimensions (id) ON DELETE CASCADE;
ALTER TABLE scoring_levels ADD CONSTRAINT fk_scoring_levels_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE scoring_bands ADD CONSTRAINT fk_scoring_bands_model_id FOREIGN KEY (model_id) REFERENCES scoring_models (id) ON DELETE CASCADE;
ALTER TABLE scoring_bands ADD CONSTRAINT fk_scoring_bands_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE kits ADD CONSTRAINT fk_kits_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE kits ADD CONSTRAINT fk_kits_sector_id FOREIGN KEY (sector_id) REFERENCES sectors (id) ON DELETE SET NULL;
ALTER TABLE kits ADD CONSTRAINT fk_kits_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE kit_editions ADD CONSTRAINT fk_kit_editions_kit_id FOREIGN KEY (kit_id) REFERENCES kits (id) ON DELETE CASCADE;
ALTER TABLE kit_editions ADD CONSTRAINT fk_kit_editions_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE CASCADE;
ALTER TABLE kit_editions ADD CONSTRAINT fk_kit_editions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE kit_items ADD CONSTRAINT fk_kit_items_kit_id FOREIGN KEY (kit_id) REFERENCES kits (id) ON DELETE CASCADE;
ALTER TABLE kit_items ADD CONSTRAINT fk_kit_items_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_templates ADD CONSTRAINT fk_document_templates_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE document_templates ADD CONSTRAINT fk_document_templates_file_id FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE SET NULL;
ALTER TABLE document_templates ADD CONSTRAINT fk_document_templates_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE template_clauses ADD CONSTRAINT fk_template_clauses_document_template_id FOREIGN KEY (document_template_id) REFERENCES document_templates (id) ON DELETE CASCADE;
ALTER TABLE template_clauses ADD CONSTRAINT fk_template_clauses_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE CASCADE;
ALTER TABLE template_clauses ADD CONSTRAINT fk_template_clauses_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE process_templates ADD CONSTRAINT fk_process_templates_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE process_templates ADD CONSTRAINT fk_process_templates_sector_id FOREIGN KEY (sector_id) REFERENCES sectors (id) ON DELETE SET NULL;
ALTER TABLE process_templates ADD CONSTRAINT fk_process_templates_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE indicator_templates ADD CONSTRAINT fk_indicator_templates_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE indicator_templates ADD CONSTRAINT fk_indicator_templates_process_template_id FOREIGN KEY (process_template_id) REFERENCES process_templates (id) ON DELETE CASCADE;
ALTER TABLE indicator_templates ADD CONSTRAINT fk_indicator_templates_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE risk_templates ADD CONSTRAINT fk_risk_templates_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE risk_templates ADD CONSTRAINT fk_risk_templates_sector_id FOREIGN KEY (sector_id) REFERENCES sectors (id) ON DELETE SET NULL;
ALTER TABLE risk_templates ADD CONSTRAINT fk_risk_templates_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE clause_evidence_expectations ADD CONSTRAINT fk_clause_evidence_expectations_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE clause_evidence_expectations ADD CONSTRAINT fk_clause_evidence_expectations_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE CASCADE;
ALTER TABLE clause_evidence_expectations ADD CONSTRAINT fk_clause_evidence_expectations_document_template_id FOREIGN KEY (document_template_id) REFERENCES document_templates (id) ON DELETE SET NULL;
ALTER TABLE clause_evidence_expectations ADD CONSTRAINT fk_clause_evidence_expectations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE certification_bodies ADD CONSTRAINT fk_certification_bodies_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE certification_bodies ADD CONSTRAINT fk_certification_bodies_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE engagements ADD CONSTRAINT fk_engagements_kit_id FOREIGN KEY (kit_id) REFERENCES kits (id) ON DELETE SET NULL;
ALTER TABLE engagements ADD CONSTRAINT fk_engagements_lead_consultant_id FOREIGN KEY (lead_consultant_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE engagements ADD CONSTRAINT fk_engagements_certification_body_id FOREIGN KEY (certification_body_id) REFERENCES certification_bodies (id) ON DELETE SET NULL;
ALTER TABLE engagements ADD CONSTRAINT fk_engagements_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE engagements ADD CONSTRAINT fk_engagements_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE engagement_editions ADD CONSTRAINT fk_engagement_editions_engagement_id FOREIGN KEY (organization_id, engagement_id) REFERENCES engagements (organization_id, id) ON DELETE CASCADE;
ALTER TABLE engagement_editions ADD CONSTRAINT fk_engagement_editions_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE RESTRICT;
ALTER TABLE engagement_editions ADD CONSTRAINT fk_engagement_editions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE engagement_editions ADD CONSTRAINT fk_engagement_editions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE engagement_milestones ADD CONSTRAINT fk_engagement_milestones_engagement_id FOREIGN KEY (organization_id, engagement_id) REFERENCES engagements (organization_id, id) ON DELETE CASCADE;
ALTER TABLE engagement_milestones ADD CONSTRAINT fk_engagement_milestones_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE engagement_milestones ADD CONSTRAINT fk_engagement_milestones_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE deliverables ADD CONSTRAINT fk_deliverables_engagement_id FOREIGN KEY (organization_id, engagement_id) REFERENCES engagements (organization_id, id) ON DELETE CASCADE;
ALTER TABLE deliverables ADD CONSTRAINT fk_deliverables_milestone_id FOREIGN KEY (organization_id, milestone_id) REFERENCES engagement_milestones (organization_id, id) ON DELETE SET NULL (milestone_id);
ALTER TABLE deliverables ADD CONSTRAINT fk_deliverables_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE deliverables ADD CONSTRAINT fk_deliverables_owner_id FOREIGN KEY (owner_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE deliverables ADD CONSTRAINT fk_deliverables_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE deliverables ADD CONSTRAINT fk_deliverables_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE consultant_visits ADD CONSTRAINT fk_consultant_visits_engagement_id FOREIGN KEY (organization_id, engagement_id) REFERENCES engagements (organization_id, id) ON DELETE CASCADE;
ALTER TABLE consultant_visits ADD CONSTRAINT fk_consultant_visits_firm_member_id FOREIGN KEY (firm_member_id) REFERENCES firm_members (id) ON DELETE RESTRICT;
ALTER TABLE consultant_visits ADD CONSTRAINT fk_consultant_visits_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE consultant_visits ADD CONSTRAINT fk_consultant_visits_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE gap_assessments ADD CONSTRAINT fk_gap_assessments_engagement_id FOREIGN KEY (organization_id, engagement_id) REFERENCES engagements (organization_id, id) ON DELETE SET NULL (engagement_id);
ALTER TABLE gap_assessments ADD CONSTRAINT fk_gap_assessments_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE RESTRICT;
ALTER TABLE gap_assessments ADD CONSTRAINT fk_gap_assessments_assessor_id FOREIGN KEY (assessor_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE gap_assessments ADD CONSTRAINT fk_gap_assessments_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE gap_assessments ADD CONSTRAINT fk_gap_assessments_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE gap_assessment_items ADD CONSTRAINT fk_gap_assessment_items_gap_assessment_id FOREIGN KEY (organization_id, gap_assessment_id) REFERENCES gap_assessments (organization_id, id) ON DELETE CASCADE;
ALTER TABLE gap_assessment_items ADD CONSTRAINT fk_gap_assessment_items_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE RESTRICT;
ALTER TABLE gap_assessment_items ADD CONSTRAINT fk_gap_assessment_items_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE gap_assessment_items ADD CONSTRAINT fk_gap_assessment_items_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE readiness_snapshots ADD CONSTRAINT fk_readiness_snapshots_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE RESTRICT;
ALTER TABLE readiness_snapshots ADD CONSTRAINT fk_readiness_snapshots_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE certificates ADD CONSTRAINT fk_certificates_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE RESTRICT;
ALTER TABLE certificates ADD CONSTRAINT fk_certificates_certification_body_id FOREIGN KEY (certification_body_id) REFERENCES certification_bodies (id) ON DELETE SET NULL;
ALTER TABLE certificates ADD CONSTRAINT fk_certificates_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE certificates ADD CONSTRAINT fk_certificates_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE management_systems ADD CONSTRAINT fk_management_systems_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE management_systems ADD CONSTRAINT fk_management_systems_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE management_systems ADD CONSTRAINT fk_management_systems_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE management_system_editions ADD CONSTRAINT fk_management_system_editions_management_system_id FOREIGN KEY (organization_id, management_system_id) REFERENCES management_systems (organization_id, id) ON DELETE CASCADE;
ALTER TABLE management_system_editions ADD CONSTRAINT fk_management_system_editions_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE RESTRICT;
ALTER TABLE management_system_editions ADD CONSTRAINT fk_management_system_editions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE management_system_editions ADD CONSTRAINT fk_management_system_editions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE clause_exclusions ADD CONSTRAINT fk_clause_exclusions_management_system_id FOREIGN KEY (organization_id, management_system_id) REFERENCES management_systems (organization_id, id) ON DELETE CASCADE;
ALTER TABLE clause_exclusions ADD CONSTRAINT fk_clause_exclusions_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE RESTRICT;
ALTER TABLE clause_exclusions ADD CONSTRAINT fk_clause_exclusions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE clause_exclusions ADD CONSTRAINT fk_clause_exclusions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE context_issues ADD CONSTRAINT fk_context_issues_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE context_issues ADD CONSTRAINT fk_context_issues_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE context_issues ADD CONSTRAINT fk_context_issues_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE interested_parties ADD CONSTRAINT fk_interested_parties_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE interested_parties ADD CONSTRAINT fk_interested_parties_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE party_requirements ADD CONSTRAINT fk_party_requirements_party_id FOREIGN KEY (organization_id, party_id) REFERENCES interested_parties (organization_id, id) ON DELETE CASCADE;
ALTER TABLE party_requirements ADD CONSTRAINT fk_party_requirements_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE party_requirements ADD CONSTRAINT fk_party_requirements_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE party_requirements ADD CONSTRAINT fk_party_requirements_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE policy_axes ADD CONSTRAINT fk_policy_axes_policy_document_id FOREIGN KEY (organization_id, policy_document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (policy_document_id);
ALTER TABLE policy_axes ADD CONSTRAINT fk_policy_axes_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE policy_axes ADD CONSTRAINT fk_policy_axes_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE processes ADD CONSTRAINT fk_processes_parent_id FOREIGN KEY (organization_id, parent_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (parent_id);
ALTER TABLE processes ADD CONSTRAINT fk_processes_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE processes ADD CONSTRAINT fk_processes_deputy_membership_id FOREIGN KEY (organization_id, deputy_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (deputy_membership_id);
ALTER TABLE processes ADD CONSTRAINT fk_processes_sheet_document_id FOREIGN KEY (organization_id, sheet_document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (sheet_document_id);
ALTER TABLE processes ADD CONSTRAINT fk_processes_template_id FOREIGN KEY (template_id) REFERENCES process_templates (id) ON DELETE SET NULL;
ALTER TABLE processes ADD CONSTRAINT fk_processes_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE processes ADD CONSTRAINT fk_processes_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE process_steps ADD CONSTRAINT fk_process_steps_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE CASCADE;
ALTER TABLE process_steps ADD CONSTRAINT fk_process_steps_responsible_position_id FOREIGN KEY (organization_id, responsible_position_id) REFERENCES positions (organization_id, id) ON DELETE SET NULL (responsible_position_id);
ALTER TABLE process_steps ADD CONSTRAINT fk_process_steps_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE process_steps ADD CONSTRAINT fk_process_steps_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE process_step_documents ADD CONSTRAINT fk_process_step_documents_step_id FOREIGN KEY (organization_id, step_id) REFERENCES process_steps (organization_id, id) ON DELETE CASCADE;
ALTER TABLE process_step_documents ADD CONSTRAINT fk_process_step_documents_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE CASCADE;
ALTER TABLE process_step_documents ADD CONSTRAINT fk_process_step_documents_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE process_step_documents ADD CONSTRAINT fk_process_step_documents_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE process_interactions ADD CONSTRAINT fk_process_interactions_from_process_id FOREIGN KEY (organization_id, from_process_id) REFERENCES processes (organization_id, id) ON DELETE CASCADE;
ALTER TABLE process_interactions ADD CONSTRAINT fk_process_interactions_to_process_id FOREIGN KEY (organization_id, to_process_id) REFERENCES processes (organization_id, id) ON DELETE CASCADE;
ALTER TABLE process_interactions ADD CONSTRAINT fk_process_interactions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE process_interactions ADD CONSTRAINT fk_process_interactions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE process_clauses ADD CONSTRAINT fk_process_clauses_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE CASCADE;
ALTER TABLE process_clauses ADD CONSTRAINT fk_process_clauses_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE RESTRICT;
ALTER TABLE process_clauses ADD CONSTRAINT fk_process_clauses_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE process_clauses ADD CONSTRAINT fk_process_clauses_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE process_reviews ADD CONSTRAINT fk_process_reviews_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE CASCADE;
ALTER TABLE process_reviews ADD CONSTRAINT fk_process_reviews_reviewer_membership_id FOREIGN KEY (organization_id, reviewer_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (reviewer_membership_id);
ALTER TABLE process_reviews ADD CONSTRAINT fk_process_reviews_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE process_reviews ADD CONSTRAINT fk_process_reviews_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE document_types ADD CONSTRAINT fk_document_types_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_types ADD CONSTRAINT fk_document_types_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE documents ADD CONSTRAINT fk_documents_document_type_id FOREIGN KEY (organization_id, document_type_id) REFERENCES document_types (organization_id, id) ON DELETE RESTRICT;
ALTER TABLE documents ADD CONSTRAINT fk_documents_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE documents ADD CONSTRAINT fk_documents_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE documents ADD CONSTRAINT fk_documents_current_version_id FOREIGN KEY (organization_id, current_version_id) REFERENCES document_versions (organization_id, id) ON DELETE SET NULL (current_version_id);
ALTER TABLE documents ADD CONSTRAINT fk_documents_template_id FOREIGN KEY (template_id) REFERENCES document_templates (id) ON DELETE SET NULL;
ALTER TABLE documents ADD CONSTRAINT fk_documents_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE documents ADD CONSTRAINT fk_documents_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE document_versions ADD CONSTRAINT fk_document_versions_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE CASCADE;
ALTER TABLE document_versions ADD CONSTRAINT fk_document_versions_file_id FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE SET NULL;
ALTER TABLE document_versions ADD CONSTRAINT fk_document_versions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_versions ADD CONSTRAINT fk_document_versions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE document_approvals ADD CONSTRAINT fk_document_approvals_version_id FOREIGN KEY (organization_id, version_id) REFERENCES document_versions (organization_id, id) ON DELETE CASCADE;
ALTER TABLE document_approvals ADD CONSTRAINT fk_document_approvals_assignee_membership_id FOREIGN KEY (organization_id, assignee_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (assignee_membership_id);
ALTER TABLE document_approvals ADD CONSTRAINT fk_document_approvals_assignee_firm_member_id FOREIGN KEY (assignee_firm_member_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE document_approvals ADD CONSTRAINT fk_document_approvals_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_approvals ADD CONSTRAINT fk_document_approvals_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE distribution_points ADD CONSTRAINT fk_distribution_points_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE distribution_points ADD CONSTRAINT fk_distribution_points_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE document_distributions ADD CONSTRAINT fk_document_distributions_version_id FOREIGN KEY (organization_id, version_id) REFERENCES document_versions (organization_id, id) ON DELETE CASCADE;
ALTER TABLE document_distributions ADD CONSTRAINT fk_document_distributions_distribution_point_id FOREIGN KEY (organization_id, distribution_point_id) REFERENCES distribution_points (organization_id, id) ON DELETE RESTRICT;
ALTER TABLE document_distributions ADD CONSTRAINT fk_document_distributions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_distributions ADD CONSTRAINT fk_document_distributions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE document_acknowledgements ADD CONSTRAINT fk_document_acknowledgements_version_id FOREIGN KEY (organization_id, version_id) REFERENCES document_versions (organization_id, id) ON DELETE CASCADE;
ALTER TABLE document_acknowledgements ADD CONSTRAINT fk_document_acknowledgements_membership_id FOREIGN KEY (organization_id, membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (membership_id);
ALTER TABLE document_acknowledgements ADD CONSTRAINT fk_document_acknowledgements_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE SET NULL (employee_id);
ALTER TABLE document_acknowledgements ADD CONSTRAINT fk_document_acknowledgements_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_acknowledgements ADD CONSTRAINT fk_document_acknowledgements_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE document_clauses ADD CONSTRAINT fk_document_clauses_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE CASCADE;
ALTER TABLE document_clauses ADD CONSTRAINT fk_document_clauses_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE RESTRICT;
ALTER TABLE document_clauses ADD CONSTRAINT fk_document_clauses_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_clauses ADD CONSTRAINT fk_document_clauses_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE document_sequences ADD CONSTRAINT fk_document_sequences_document_type_id FOREIGN KEY (organization_id, document_type_id) REFERENCES document_types (organization_id, id) ON DELETE CASCADE;
ALTER TABLE document_sequences ADD CONSTRAINT fk_document_sequences_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE CASCADE;
ALTER TABLE document_sequences ADD CONSTRAINT fk_document_sequences_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE document_sequences ADD CONSTRAINT fk_document_sequences_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE register_definitions ADD CONSTRAINT fk_register_definitions_firm_id FOREIGN KEY (firm_id) REFERENCES firms (id) ON DELETE CASCADE;
ALTER TABLE register_definitions ADD CONSTRAINT fk_register_definitions_org_id FOREIGN KEY (org_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE register_definitions ADD CONSTRAINT fk_register_definitions_document_id FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL;
ALTER TABLE register_definitions ADD CONSTRAINT fk_register_definitions_process_id FOREIGN KEY (process_id) REFERENCES processes (id) ON DELETE SET NULL;
ALTER TABLE register_definitions ADD CONSTRAINT fk_register_definitions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE register_entries ADD CONSTRAINT fk_register_entries_definition_id FOREIGN KEY (definition_id) REFERENCES register_definitions (id) ON DELETE CASCADE;
ALTER TABLE register_entries ADD CONSTRAINT fk_register_entries_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE register_entries ADD CONSTRAINT fk_register_entries_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE register_entries ADD CONSTRAINT fk_register_entries_project_id FOREIGN KEY (organization_id, project_id) REFERENCES projects (organization_id, id) ON DELETE SET NULL (project_id);
ALTER TABLE register_entries ADD CONSTRAINT fk_register_entries_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE register_entries ADD CONSTRAINT fk_register_entries_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE change_requests ADD CONSTRAINT fk_change_requests_requested_by FOREIGN KEY (organization_id, requested_by) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (requested_by);
ALTER TABLE change_requests ADD CONSTRAINT fk_change_requests_approved_by FOREIGN KEY (organization_id, approved_by) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (approved_by);
ALTER TABLE change_requests ADD CONSTRAINT fk_change_requests_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE change_requests ADD CONSTRAINT fk_change_requests_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE change_impacts ADD CONSTRAINT fk_change_impacts_change_request_id FOREIGN KEY (organization_id, change_request_id) REFERENCES change_requests (organization_id, id) ON DELETE CASCADE;
ALTER TABLE change_impacts ADD CONSTRAINT fk_change_impacts_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE change_impacts ADD CONSTRAINT fk_change_impacts_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE knowledge_items ADD CONSTRAINT fk_knowledge_items_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE knowledge_items ADD CONSTRAINT fk_knowledge_items_holder_employee_id FOREIGN KEY (organization_id, holder_employee_id) REFERENCES employees (organization_id, id) ON DELETE SET NULL (holder_employee_id);
ALTER TABLE knowledge_items ADD CONSTRAINT fk_knowledge_items_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE knowledge_items ADD CONSTRAINT fk_knowledge_items_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE knowledge_items ADD CONSTRAINT fk_knowledge_items_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE activities ADD CONSTRAINT fk_activities_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE activities ADD CONSTRAINT fk_activities_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE activities ADD CONSTRAINT fk_activities_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE activities ADD CONSTRAINT fk_activities_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE risk_assessments ADD CONSTRAINT fk_risk_assessments_scoring_model_id FOREIGN KEY (scoring_model_id) REFERENCES scoring_models (id) ON DELETE RESTRICT;
ALTER TABLE risk_assessments ADD CONSTRAINT fk_risk_assessments_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE risk_assessments ADD CONSTRAINT fk_risk_assessments_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE risk_assessments ADD CONSTRAINT fk_risk_assessments_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_assessment_id FOREIGN KEY (organization_id, assessment_id) REFERENCES risk_assessments (organization_id, id) ON DELETE CASCADE;
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_activity_id FOREIGN KEY (organization_id, activity_id) REFERENCES activities (organization_id, id) ON DELETE SET NULL (activity_id);
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_context_issue_id FOREIGN KEY (organization_id, context_issue_id) REFERENCES context_issues (organization_id, id) ON DELETE SET NULL (context_issue_id);
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_interested_party_id FOREIGN KEY (organization_id, interested_party_id) REFERENCES interested_parties (organization_id, id) ON DELETE SET NULL (interested_party_id);
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_current_band_id FOREIGN KEY (current_band_id) REFERENCES scoring_bands (id) ON DELETE SET NULL;
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_template_id FOREIGN KEY (template_id) REFERENCES risk_templates (id) ON DELETE SET NULL;
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE risk_items ADD CONSTRAINT fk_risk_items_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE ohs_hazard_details ADD CONSTRAINT fk_ohs_hazard_details_risk_item_id FOREIGN KEY (organization_id, risk_item_id) REFERENCES risk_items (organization_id, id) ON DELETE CASCADE;
ALTER TABLE ohs_hazard_details ADD CONSTRAINT fk_ohs_hazard_details_regulatory_requirement_id FOREIGN KEY (regulatory_requirement_id) REFERENCES regulatory_requirements (id) ON DELETE SET NULL;
ALTER TABLE ohs_hazard_details ADD CONSTRAINT fk_ohs_hazard_details_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE ohs_hazard_details ADD CONSTRAINT fk_ohs_hazard_details_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE env_aspect_details ADD CONSTRAINT fk_env_aspect_details_risk_item_id FOREIGN KEY (organization_id, risk_item_id) REFERENCES risk_items (organization_id, id) ON DELETE CASCADE;
ALTER TABLE env_aspect_details ADD CONSTRAINT fk_env_aspect_details_regulatory_requirement_id FOREIGN KEY (regulatory_requirement_id) REFERENCES regulatory_requirements (id) ON DELETE SET NULL;
ALTER TABLE env_aspect_details ADD CONSTRAINT fk_env_aspect_details_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE env_aspect_details ADD CONSTRAINT fk_env_aspect_details_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE risk_evaluations ADD CONSTRAINT fk_risk_evaluations_risk_item_id FOREIGN KEY (organization_id, risk_item_id) REFERENCES risk_items (organization_id, id) ON DELETE CASCADE;
ALTER TABLE risk_evaluations ADD CONSTRAINT fk_risk_evaluations_evaluator_membership_id FOREIGN KEY (organization_id, evaluator_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (evaluator_membership_id);
ALTER TABLE risk_evaluations ADD CONSTRAINT fk_risk_evaluations_band_id FOREIGN KEY (band_id) REFERENCES scoring_bands (id) ON DELETE SET NULL;
ALTER TABLE risk_evaluations ADD CONSTRAINT fk_risk_evaluations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE risk_evaluations ADD CONSTRAINT fk_risk_evaluations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE risk_evaluation_scores ADD CONSTRAINT fk_risk_evaluation_scores_evaluation_id FOREIGN KEY (organization_id, evaluation_id) REFERENCES risk_evaluations (organization_id, id) ON DELETE CASCADE;
ALTER TABLE risk_evaluation_scores ADD CONSTRAINT fk_risk_evaluation_scores_dimension_id FOREIGN KEY (dimension_id) REFERENCES scoring_dimensions (id) ON DELETE RESTRICT;
ALTER TABLE risk_evaluation_scores ADD CONSTRAINT fk_risk_evaluation_scores_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE risk_evaluation_scores ADD CONSTRAINT fk_risk_evaluation_scores_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE emergency_situations ADD CONSTRAINT fk_emergency_situations_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE emergency_situations ADD CONSTRAINT fk_emergency_situations_risk_item_id FOREIGN KEY (organization_id, risk_item_id) REFERENCES risk_items (organization_id, id) ON DELETE SET NULL (risk_item_id);
ALTER TABLE emergency_situations ADD CONSTRAINT fk_emergency_situations_response_document_id FOREIGN KEY (organization_id, response_document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (response_document_id);
ALTER TABLE emergency_situations ADD CONSTRAINT fk_emergency_situations_responsible_membership_id FOREIGN KEY (organization_id, responsible_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (responsible_membership_id);
ALTER TABLE emergency_situations ADD CONSTRAINT fk_emergency_situations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE emergency_situations ADD CONSTRAINT fk_emergency_situations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE emergency_drills ADD CONSTRAINT fk_emergency_drills_emergency_situation_id FOREIGN KEY (organization_id, emergency_situation_id) REFERENCES emergency_situations (organization_id, id) ON DELETE RESTRICT;
ALTER TABLE emergency_drills ADD CONSTRAINT fk_emergency_drills_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE emergency_drills ADD CONSTRAINT fk_emergency_drills_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE emergency_drills ADD CONSTRAINT fk_emergency_drills_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE hazardous_substances ADD CONSTRAINT fk_hazardous_substances_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE hazardous_substances ADD CONSTRAINT fk_hazardous_substances_supplier_id FOREIGN KEY (organization_id, supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (supplier_id);
ALTER TABLE hazardous_substances ADD CONSTRAINT fk_hazardous_substances_sds_file_id FOREIGN KEY (sds_file_id) REFERENCES files (id) ON DELETE SET NULL;
ALTER TABLE hazardous_substances ADD CONSTRAINT fk_hazardous_substances_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE hazardous_substances ADD CONSTRAINT fk_hazardous_substances_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE compliance_obligations ADD CONSTRAINT fk_compliance_obligations_regulatory_text_id FOREIGN KEY (regulatory_text_id) REFERENCES regulatory_texts (id) ON DELETE SET NULL;
ALTER TABLE compliance_obligations ADD CONSTRAINT fk_compliance_obligations_regulatory_requirement_id FOREIGN KEY (regulatory_requirement_id) REFERENCES regulatory_requirements (id) ON DELETE SET NULL;
ALTER TABLE compliance_obligations ADD CONSTRAINT fk_compliance_obligations_party_requirement_id FOREIGN KEY (organization_id, party_requirement_id) REFERENCES party_requirements (organization_id, id) ON DELETE SET NULL (party_requirement_id);
ALTER TABLE compliance_obligations ADD CONSTRAINT fk_compliance_obligations_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE compliance_obligations ADD CONSTRAINT fk_compliance_obligations_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE compliance_obligations ADD CONSTRAINT fk_compliance_obligations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE compliance_obligations ADD CONSTRAINT fk_compliance_obligations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE compliance_evaluations ADD CONSTRAINT fk_compliance_evaluations_obligation_id FOREIGN KEY (organization_id, obligation_id) REFERENCES compliance_obligations (organization_id, id) ON DELETE CASCADE;
ALTER TABLE compliance_evaluations ADD CONSTRAINT fk_compliance_evaluations_evaluator_membership_id FOREIGN KEY (organization_id, evaluator_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (evaluator_membership_id);
ALTER TABLE compliance_evaluations ADD CONSTRAINT fk_compliance_evaluations_evaluator_firm_member_id FOREIGN KEY (evaluator_firm_member_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE compliance_evaluations ADD CONSTRAINT fk_compliance_evaluations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE compliance_evaluations ADD CONSTRAINT fk_compliance_evaluations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE objectives ADD CONSTRAINT fk_objectives_policy_axis_id FOREIGN KEY (organization_id, policy_axis_id) REFERENCES policy_axes (organization_id, id) ON DELETE SET NULL (policy_axis_id);
ALTER TABLE objectives ADD CONSTRAINT fk_objectives_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE objectives ADD CONSTRAINT fk_objectives_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE objectives ADD CONSTRAINT fk_objectives_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE objectives ADD CONSTRAINT fk_objectives_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE indicators ADD CONSTRAINT fk_indicators_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE indicators ADD CONSTRAINT fk_indicators_objective_id FOREIGN KEY (organization_id, objective_id) REFERENCES objectives (organization_id, id) ON DELETE SET NULL (objective_id);
ALTER TABLE indicators ADD CONSTRAINT fk_indicators_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE indicators ADD CONSTRAINT fk_indicators_template_id FOREIGN KEY (template_id) REFERENCES indicator_templates (id) ON DELETE SET NULL;
ALTER TABLE indicators ADD CONSTRAINT fk_indicators_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE indicators ADD CONSTRAINT fk_indicators_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE indicator_measurements ADD CONSTRAINT fk_indicator_measurements_indicator_id FOREIGN KEY (organization_id, indicator_id) REFERENCES indicators (organization_id, id) ON DELETE CASCADE;
ALTER TABLE indicator_measurements ADD CONSTRAINT fk_indicator_measurements_entered_by_membership_id FOREIGN KEY (organization_id, entered_by_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (entered_by_membership_id);
ALTER TABLE indicator_measurements ADD CONSTRAINT fk_indicator_measurements_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE indicator_measurements ADD CONSTRAINT fk_indicator_measurements_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE customers ADD CONSTRAINT fk_customers_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE customers ADD CONSTRAINT fk_customers_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE projects ADD CONSTRAINT fk_projects_customer_id FOREIGN KEY (organization_id, customer_id) REFERENCES customers (organization_id, id) ON DELETE SET NULL (customer_id);
ALTER TABLE projects ADD CONSTRAINT fk_projects_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE projects ADD CONSTRAINT fk_projects_manager_membership_id FOREIGN KEY (organization_id, manager_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (manager_membership_id);
ALTER TABLE projects ADD CONSTRAINT fk_projects_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE projects ADD CONSTRAINT fk_projects_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE customer_surveys ADD CONSTRAINT fk_customer_surveys_customer_id FOREIGN KEY (organization_id, customer_id) REFERENCES customers (organization_id, id) ON DELETE SET NULL (customer_id);
ALTER TABLE customer_surveys ADD CONSTRAINT fk_customer_surveys_project_id FOREIGN KEY (organization_id, project_id) REFERENCES projects (organization_id, id) ON DELETE SET NULL (project_id);
ALTER TABLE customer_surveys ADD CONSTRAINT fk_customer_surveys_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE customer_surveys ADD CONSTRAINT fk_customer_surveys_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE complaints ADD CONSTRAINT fk_complaints_customer_id FOREIGN KEY (organization_id, customer_id) REFERENCES customers (organization_id, id) ON DELETE SET NULL (customer_id);
ALTER TABLE complaints ADD CONSTRAINT fk_complaints_project_id FOREIGN KEY (organization_id, project_id) REFERENCES projects (organization_id, id) ON DELETE SET NULL (project_id);
ALTER TABLE complaints ADD CONSTRAINT fk_complaints_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE complaints ADD CONSTRAINT fk_complaints_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE incidents ADD CONSTRAINT fk_incidents_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE incidents ADD CONSTRAINT fk_incidents_project_id FOREIGN KEY (organization_id, project_id) REFERENCES projects (organization_id, id) ON DELETE SET NULL (project_id);
ALTER TABLE incidents ADD CONSTRAINT fk_incidents_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE SET NULL (employee_id);
ALTER TABLE incidents ADD CONSTRAINT fk_incidents_reported_by_membership_id FOREIGN KEY (organization_id, reported_by_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (reported_by_membership_id);
ALTER TABLE incidents ADD CONSTRAINT fk_incidents_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE incidents ADD CONSTRAINT fk_incidents_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_project_id FOREIGN KEY (organization_id, project_id) REFERENCES projects (organization_id, id) ON DELETE SET NULL (project_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_supplier_id FOREIGN KEY (organization_id, supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (supplier_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_detected_by_membership_id FOREIGN KEY (organization_id, detected_by_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (detected_by_membership_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_detected_by_firm_member_id FOREIGN KEY (detected_by_firm_member_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_audit_finding_id FOREIGN KEY (organization_id, audit_finding_id) REFERENCES audit_findings (organization_id, id) ON DELETE SET NULL (audit_finding_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_gap_assessment_item_id FOREIGN KEY (organization_id, gap_assessment_item_id) REFERENCES gap_assessment_items (organization_id, id) ON DELETE SET NULL (gap_assessment_item_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_indicator_measurement_id FOREIGN KEY (organization_id, indicator_measurement_id) REFERENCES indicator_measurements (organization_id, id) ON DELETE SET NULL (indicator_measurement_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_complaint_id FOREIGN KEY (organization_id, complaint_id) REFERENCES complaints (organization_id, id) ON DELETE SET NULL (complaint_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_incident_id FOREIGN KEY (organization_id, incident_id) REFERENCES incidents (organization_id, id) ON DELETE SET NULL (incident_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_emergency_drill_id FOREIGN KEY (organization_id, emergency_drill_id) REFERENCES emergency_drills (organization_id, id) ON DELETE SET NULL (emergency_drill_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_compliance_evaluation_id FOREIGN KEY (organization_id, compliance_evaluation_id) REFERENCES compliance_evaluations (organization_id, id) ON DELETE SET NULL (compliance_evaluation_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_inspection_result_id FOREIGN KEY (organization_id, inspection_result_id) REFERENCES inspection_results (organization_id, id) ON DELETE SET NULL (inspection_result_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_management_review_id FOREIGN KEY (organization_id, management_review_id) REFERENCES management_reviews (organization_id, id) ON DELETE SET NULL (management_review_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_worker_meeting_id FOREIGN KEY (organization_id, worker_meeting_id) REFERENCES worker_meetings (organization_id, id) ON DELETE SET NULL (worker_meeting_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_register_entry_id FOREIGN KEY (organization_id, register_entry_id) REFERENCES register_entries (organization_id, id) ON DELETE SET NULL (register_entry_id);
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE nonconformities ADD CONSTRAINT fk_nonconformities_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE nonconformity_clauses ADD CONSTRAINT fk_nonconformity_clauses_nonconformity_id FOREIGN KEY (organization_id, nonconformity_id) REFERENCES nonconformities (organization_id, id) ON DELETE CASCADE;
ALTER TABLE nonconformity_clauses ADD CONSTRAINT fk_nonconformity_clauses_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE RESTRICT;
ALTER TABLE nonconformity_clauses ADD CONSTRAINT fk_nonconformity_clauses_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE nonconformity_clauses ADD CONSTRAINT fk_nonconformity_clauses_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE actions ADD CONSTRAINT fk_actions_efficacy_verified_by FOREIGN KEY (organization_id, efficacy_verified_by) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (efficacy_verified_by);
ALTER TABLE actions ADD CONSTRAINT fk_actions_nonconformity_id FOREIGN KEY (organization_id, nonconformity_id) REFERENCES nonconformities (organization_id, id) ON DELETE CASCADE;
ALTER TABLE actions ADD CONSTRAINT fk_actions_risk_item_id FOREIGN KEY (organization_id, risk_item_id) REFERENCES risk_items (organization_id, id) ON DELETE SET NULL (risk_item_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_objective_id FOREIGN KEY (organization_id, objective_id) REFERENCES objectives (organization_id, id) ON DELETE SET NULL (objective_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_audit_finding_id FOREIGN KEY (organization_id, audit_finding_id) REFERENCES audit_findings (organization_id, id) ON DELETE SET NULL (audit_finding_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_management_review_decision_id FOREIGN KEY (organization_id, management_review_decision_id) REFERENCES management_review_decisions (organization_id, id) ON DELETE SET NULL (management_review_decision_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_gap_assessment_item_id FOREIGN KEY (organization_id, gap_assessment_item_id) REFERENCES gap_assessment_items (organization_id, id) ON DELETE SET NULL (gap_assessment_item_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_compliance_evaluation_id FOREIGN KEY (organization_id, compliance_evaluation_id) REFERENCES compliance_evaluations (organization_id, id) ON DELETE SET NULL (compliance_evaluation_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_change_request_id FOREIGN KEY (organization_id, change_request_id) REFERENCES change_requests (organization_id, id) ON DELETE SET NULL (change_request_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_worker_meeting_id FOREIGN KEY (organization_id, worker_meeting_id) REFERENCES worker_meetings (organization_id, id) ON DELETE SET NULL (worker_meeting_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_emergency_drill_id FOREIGN KEY (organization_id, emergency_drill_id) REFERENCES emergency_drills (organization_id, id) ON DELETE SET NULL (emergency_drill_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_equipment_check_id FOREIGN KEY (organization_id, equipment_check_id) REFERENCES equipment_checks (organization_id, id) ON DELETE SET NULL (equipment_check_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_inspection_id FOREIGN KEY (organization_id, inspection_id) REFERENCES inspections (organization_id, id) ON DELETE SET NULL (inspection_id);
ALTER TABLE actions ADD CONSTRAINT fk_actions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE actions ADD CONSTRAINT fk_actions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE action_owners ADD CONSTRAINT fk_action_owners_action_id FOREIGN KEY (organization_id, action_id) REFERENCES actions (organization_id, id) ON DELETE CASCADE;
ALTER TABLE action_owners ADD CONSTRAINT fk_action_owners_membership_id FOREIGN KEY (organization_id, membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE CASCADE;
ALTER TABLE action_owners ADD CONSTRAINT fk_action_owners_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE action_owners ADD CONSTRAINT fk_action_owners_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE action_updates ADD CONSTRAINT fk_action_updates_action_id FOREIGN KEY (organization_id, action_id) REFERENCES actions (organization_id, id) ON DELETE CASCADE;
ALTER TABLE action_updates ADD CONSTRAINT fk_action_updates_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE action_updates ADD CONSTRAINT fk_action_updates_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audit_programs ADD CONSTRAINT fk_audit_programs_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE audit_programs ADD CONSTRAINT fk_audit_programs_approved_by FOREIGN KEY (organization_id, approved_by) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (approved_by);
ALTER TABLE audit_programs ADD CONSTRAINT fk_audit_programs_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audit_programs ADD CONSTRAINT fk_audit_programs_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audit_program_items ADD CONSTRAINT fk_audit_program_items_program_id FOREIGN KEY (organization_id, program_id) REFERENCES audit_programs (organization_id, id) ON DELETE CASCADE;
ALTER TABLE audit_program_items ADD CONSTRAINT fk_audit_program_items_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE audit_program_items ADD CONSTRAINT fk_audit_program_items_audit_id FOREIGN KEY (organization_id, audit_id) REFERENCES audits (organization_id, id) ON DELETE SET NULL (audit_id);
ALTER TABLE audit_program_items ADD CONSTRAINT fk_audit_program_items_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audit_program_items ADD CONSTRAINT fk_audit_program_items_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audits ADD CONSTRAINT fk_audits_supplier_id FOREIGN KEY (organization_id, supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (supplier_id);
ALTER TABLE audits ADD CONSTRAINT fk_audits_certification_body_id FOREIGN KEY (certification_body_id) REFERENCES certification_bodies (id) ON DELETE SET NULL;
ALTER TABLE audits ADD CONSTRAINT fk_audits_engagement_id FOREIGN KEY (organization_id, engagement_id) REFERENCES engagements (organization_id, id) ON DELETE SET NULL (engagement_id);
ALTER TABLE audits ADD CONSTRAINT fk_audits_report_document_id FOREIGN KEY (organization_id, report_document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (report_document_id);
ALTER TABLE audits ADD CONSTRAINT fk_audits_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audits ADD CONSTRAINT fk_audits_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audit_editions ADD CONSTRAINT fk_audit_editions_audit_id FOREIGN KEY (organization_id, audit_id) REFERENCES audits (organization_id, id) ON DELETE CASCADE;
ALTER TABLE audit_editions ADD CONSTRAINT fk_audit_editions_edition_id FOREIGN KEY (edition_id) REFERENCES standard_editions (id) ON DELETE RESTRICT;
ALTER TABLE audit_editions ADD CONSTRAINT fk_audit_editions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audit_editions ADD CONSTRAINT fk_audit_editions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audit_team_members ADD CONSTRAINT fk_audit_team_members_audit_id FOREIGN KEY (organization_id, audit_id) REFERENCES audits (organization_id, id) ON DELETE CASCADE;
ALTER TABLE audit_team_members ADD CONSTRAINT fk_audit_team_members_membership_id FOREIGN KEY (organization_id, membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (membership_id);
ALTER TABLE audit_team_members ADD CONSTRAINT fk_audit_team_members_firm_member_id FOREIGN KEY (firm_member_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE audit_team_members ADD CONSTRAINT fk_audit_team_members_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audit_team_members ADD CONSTRAINT fk_audit_team_members_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audit_plan_slots ADD CONSTRAINT fk_audit_plan_slots_audit_id FOREIGN KEY (organization_id, audit_id) REFERENCES audits (organization_id, id) ON DELETE CASCADE;
ALTER TABLE audit_plan_slots ADD CONSTRAINT fk_audit_plan_slots_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE audit_plan_slots ADD CONSTRAINT fk_audit_plan_slots_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE audit_plan_slots ADD CONSTRAINT fk_audit_plan_slots_team_member_id FOREIGN KEY (organization_id, team_member_id) REFERENCES audit_team_members (organization_id, id) ON DELETE SET NULL (team_member_id);
ALTER TABLE audit_plan_slots ADD CONSTRAINT fk_audit_plan_slots_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audit_plan_slots ADD CONSTRAINT fk_audit_plan_slots_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audit_checklist_items ADD CONSTRAINT fk_audit_checklist_items_audit_id FOREIGN KEY (organization_id, audit_id) REFERENCES audits (organization_id, id) ON DELETE CASCADE;
ALTER TABLE audit_checklist_items ADD CONSTRAINT fk_audit_checklist_items_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE SET NULL;
ALTER TABLE audit_checklist_items ADD CONSTRAINT fk_audit_checklist_items_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE audit_checklist_items ADD CONSTRAINT fk_audit_checklist_items_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audit_checklist_items ADD CONSTRAINT fk_audit_checklist_items_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE audit_findings ADD CONSTRAINT fk_audit_findings_audit_id FOREIGN KEY (organization_id, audit_id) REFERENCES audits (organization_id, id) ON DELETE CASCADE;
ALTER TABLE audit_findings ADD CONSTRAINT fk_audit_findings_clause_id FOREIGN KEY (clause_id) REFERENCES clauses (id) ON DELETE SET NULL;
ALTER TABLE audit_findings ADD CONSTRAINT fk_audit_findings_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE audit_findings ADD CONSTRAINT fk_audit_findings_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE audit_findings ADD CONSTRAINT fk_audit_findings_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE audit_findings ADD CONSTRAINT fk_audit_findings_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE management_reviews ADD CONSTRAINT fk_management_reviews_chair_membership_id FOREIGN KEY (organization_id, chair_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (chair_membership_id);
ALTER TABLE management_reviews ADD CONSTRAINT fk_management_reviews_minutes_document_id FOREIGN KEY (organization_id, minutes_document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (minutes_document_id);
ALTER TABLE management_reviews ADD CONSTRAINT fk_management_reviews_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE management_reviews ADD CONSTRAINT fk_management_reviews_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE management_review_participants ADD CONSTRAINT fk_management_review_participants_review_id FOREIGN KEY (organization_id, review_id) REFERENCES management_reviews (organization_id, id) ON DELETE CASCADE;
ALTER TABLE management_review_participants ADD CONSTRAINT fk_management_review_participants_membership_id FOREIGN KEY (organization_id, membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (membership_id);
ALTER TABLE management_review_participants ADD CONSTRAINT fk_management_review_participants_firm_member_id FOREIGN KEY (firm_member_id) REFERENCES firm_members (id) ON DELETE SET NULL;
ALTER TABLE management_review_participants ADD CONSTRAINT fk_management_review_participants_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE management_review_participants ADD CONSTRAINT fk_management_review_participants_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE management_review_inputs ADD CONSTRAINT fk_management_review_inputs_review_id FOREIGN KEY (organization_id, review_id) REFERENCES management_reviews (organization_id, id) ON DELETE CASCADE;
ALTER TABLE management_review_inputs ADD CONSTRAINT fk_management_review_inputs_prepared_by FOREIGN KEY (organization_id, prepared_by) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (prepared_by);
ALTER TABLE management_review_inputs ADD CONSTRAINT fk_management_review_inputs_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE management_review_inputs ADD CONSTRAINT fk_management_review_inputs_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE management_review_decisions ADD CONSTRAINT fk_management_review_decisions_review_id FOREIGN KEY (organization_id, review_id) REFERENCES management_reviews (organization_id, id) ON DELETE CASCADE;
ALTER TABLE management_review_decisions ADD CONSTRAINT fk_management_review_decisions_owner_membership_id FOREIGN KEY (organization_id, owner_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (owner_membership_id);
ALTER TABLE management_review_decisions ADD CONSTRAINT fk_management_review_decisions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE management_review_decisions ADD CONSTRAINT fk_management_review_decisions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE positions ADD CONSTRAINT fk_positions_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE positions ADD CONSTRAINT fk_positions_reports_to_id FOREIGN KEY (organization_id, reports_to_id) REFERENCES positions (organization_id, id) ON DELETE SET NULL (reports_to_id);
ALTER TABLE positions ADD CONSTRAINT fk_positions_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE positions ADD CONSTRAINT fk_positions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE positions ADD CONSTRAINT fk_positions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE employees ADD CONSTRAINT fk_employees_membership_id FOREIGN KEY (organization_id, membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (membership_id);
ALTER TABLE employees ADD CONSTRAINT fk_employees_position_id FOREIGN KEY (organization_id, position_id) REFERENCES positions (organization_id, id) ON DELETE SET NULL (position_id);
ALTER TABLE employees ADD CONSTRAINT fk_employees_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE employees ADD CONSTRAINT fk_employees_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE employees ADD CONSTRAINT fk_employees_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE competencies ADD CONSTRAINT fk_competencies_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE competencies ADD CONSTRAINT fk_competencies_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE position_competencies ADD CONSTRAINT fk_position_competencies_position_id FOREIGN KEY (organization_id, position_id) REFERENCES positions (organization_id, id) ON DELETE CASCADE;
ALTER TABLE position_competencies ADD CONSTRAINT fk_position_competencies_competency_id FOREIGN KEY (organization_id, competency_id) REFERENCES competencies (organization_id, id) ON DELETE CASCADE;
ALTER TABLE position_competencies ADD CONSTRAINT fk_position_competencies_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE position_competencies ADD CONSTRAINT fk_position_competencies_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE competency_evaluations ADD CONSTRAINT fk_competency_evaluations_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE competency_evaluations ADD CONSTRAINT fk_competency_evaluations_competency_id FOREIGN KEY (organization_id, competency_id) REFERENCES competencies (organization_id, id) ON DELETE RESTRICT;
ALTER TABLE competency_evaluations ADD CONSTRAINT fk_competency_evaluations_evaluator_membership_id FOREIGN KEY (organization_id, evaluator_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (evaluator_membership_id);
ALTER TABLE competency_evaluations ADD CONSTRAINT fk_competency_evaluations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE competency_evaluations ADD CONSTRAINT fk_competency_evaluations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE employee_qualifications ADD CONSTRAINT fk_employee_qualifications_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE employee_qualifications ADD CONSTRAINT fk_employee_qualifications_competency_id FOREIGN KEY (organization_id, competency_id) REFERENCES competencies (organization_id, id) ON DELETE RESTRICT;
ALTER TABLE employee_qualifications ADD CONSTRAINT fk_employee_qualifications_issuer_supplier_id FOREIGN KEY (organization_id, issuer_supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (issuer_supplier_id);
ALTER TABLE employee_qualifications ADD CONSTRAINT fk_employee_qualifications_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE employee_qualifications ADD CONSTRAINT fk_employee_qualifications_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE training_needs ADD CONSTRAINT fk_training_needs_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE training_needs ADD CONSTRAINT fk_training_needs_position_id FOREIGN KEY (organization_id, position_id) REFERENCES positions (organization_id, id) ON DELETE SET NULL (position_id);
ALTER TABLE training_needs ADD CONSTRAINT fk_training_needs_competency_id FOREIGN KEY (organization_id, competency_id) REFERENCES competencies (organization_id, id) ON DELETE SET NULL (competency_id);
ALTER TABLE training_needs ADD CONSTRAINT fk_training_needs_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE training_needs ADD CONSTRAINT fk_training_needs_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE training_plans ADD CONSTRAINT fk_training_plans_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE training_plans ADD CONSTRAINT fk_training_plans_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE training_plans ADD CONSTRAINT fk_training_plans_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE training_sessions ADD CONSTRAINT fk_training_sessions_plan_id FOREIGN KEY (organization_id, plan_id) REFERENCES training_plans (organization_id, id) ON DELETE SET NULL (plan_id);
ALTER TABLE training_sessions ADD CONSTRAINT fk_training_sessions_need_id FOREIGN KEY (organization_id, need_id) REFERENCES training_needs (organization_id, id) ON DELETE SET NULL (need_id);
ALTER TABLE training_sessions ADD CONSTRAINT fk_training_sessions_competency_id FOREIGN KEY (organization_id, competency_id) REFERENCES competencies (organization_id, id) ON DELETE SET NULL (competency_id);
ALTER TABLE training_sessions ADD CONSTRAINT fk_training_sessions_provider_supplier_id FOREIGN KEY (organization_id, provider_supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (provider_supplier_id);
ALTER TABLE training_sessions ADD CONSTRAINT fk_training_sessions_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE training_sessions ADD CONSTRAINT fk_training_sessions_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE training_sessions ADD CONSTRAINT fk_training_sessions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE training_attendances ADD CONSTRAINT fk_training_attendances_session_id FOREIGN KEY (organization_id, session_id) REFERENCES training_sessions (organization_id, id) ON DELETE CASCADE;
ALTER TABLE training_attendances ADD CONSTRAINT fk_training_attendances_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE training_attendances ADD CONSTRAINT fk_training_attendances_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE training_attendances ADD CONSTRAINT fk_training_attendances_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE recruitment_requests ADD CONSTRAINT fk_recruitment_requests_position_id FOREIGN KEY (organization_id, position_id) REFERENCES positions (organization_id, id) ON DELETE SET NULL (position_id);
ALTER TABLE recruitment_requests ADD CONSTRAINT fk_recruitment_requests_requested_by FOREIGN KEY (organization_id, requested_by) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (requested_by);
ALTER TABLE recruitment_requests ADD CONSTRAINT fk_recruitment_requests_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE recruitment_requests ADD CONSTRAINT fk_recruitment_requests_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE onboarding_plans ADD CONSTRAINT fk_onboarding_plans_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE onboarding_plans ADD CONSTRAINT fk_onboarding_plans_tutor_employee_id FOREIGN KEY (organization_id, tutor_employee_id) REFERENCES employees (organization_id, id) ON DELETE SET NULL (tutor_employee_id);
ALTER TABLE onboarding_plans ADD CONSTRAINT fk_onboarding_plans_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE onboarding_plans ADD CONSTRAINT fk_onboarding_plans_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE medical_visits ADD CONSTRAINT fk_medical_visits_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE medical_visits ADD CONSTRAINT fk_medical_visits_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE medical_visits ADD CONSTRAINT fk_medical_visits_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE ppe_issues ADD CONSTRAINT fk_ppe_issues_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE ppe_issues ADD CONSTRAINT fk_ppe_issues_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE ppe_issues ADD CONSTRAINT fk_ppe_issues_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE communication_plan_items ADD CONSTRAINT fk_communication_plan_items_sender_membership_id FOREIGN KEY (organization_id, sender_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (sender_membership_id);
ALTER TABLE communication_plan_items ADD CONSTRAINT fk_communication_plan_items_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE communication_plan_items ADD CONSTRAINT fk_communication_plan_items_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE communication_plan_items ADD CONSTRAINT fk_communication_plan_items_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE communication_records ADD CONSTRAINT fk_communication_records_plan_item_id FOREIGN KEY (organization_id, plan_item_id) REFERENCES communication_plan_items (organization_id, id) ON DELETE SET NULL (plan_item_id);
ALTER TABLE communication_records ADD CONSTRAINT fk_communication_records_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE communication_records ADD CONSTRAINT fk_communication_records_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE worker_meetings ADD CONSTRAINT fk_worker_meetings_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE worker_meetings ADD CONSTRAINT fk_worker_meetings_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE worker_meeting_participants ADD CONSTRAINT fk_worker_meeting_participants_meeting_id FOREIGN KEY (organization_id, meeting_id) REFERENCES worker_meetings (organization_id, id) ON DELETE CASCADE;
ALTER TABLE worker_meeting_participants ADD CONSTRAINT fk_worker_meeting_participants_employee_id FOREIGN KEY (organization_id, employee_id) REFERENCES employees (organization_id, id) ON DELETE CASCADE;
ALTER TABLE worker_meeting_participants ADD CONSTRAINT fk_worker_meeting_participants_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE worker_meeting_participants ADD CONSTRAINT fk_worker_meeting_participants_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE visitor_logs ADD CONSTRAINT fk_visitor_logs_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE visitor_logs ADD CONSTRAINT fk_visitor_logs_host_employee_id FOREIGN KEY (organization_id, host_employee_id) REFERENCES employees (organization_id, id) ON DELETE SET NULL (host_employee_id);
ALTER TABLE visitor_logs ADD CONSTRAINT fk_visitor_logs_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE visitor_logs ADD CONSTRAINT fk_visitor_logs_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE suppliers ADD CONSTRAINT fk_suppliers_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE suppliers ADD CONSTRAINT fk_suppliers_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE supplier_criteria ADD CONSTRAINT fk_supplier_criteria_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE supplier_criteria ADD CONSTRAINT fk_supplier_criteria_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE supplier_evaluations ADD CONSTRAINT fk_supplier_evaluations_supplier_id FOREIGN KEY (organization_id, supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE CASCADE;
ALTER TABLE supplier_evaluations ADD CONSTRAINT fk_supplier_evaluations_evaluator_membership_id FOREIGN KEY (organization_id, evaluator_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (evaluator_membership_id);
ALTER TABLE supplier_evaluations ADD CONSTRAINT fk_supplier_evaluations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE supplier_evaluations ADD CONSTRAINT fk_supplier_evaluations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE supplier_evaluation_scores ADD CONSTRAINT fk_supplier_evaluation_scores_evaluation_id FOREIGN KEY (organization_id, evaluation_id) REFERENCES supplier_evaluations (organization_id, id) ON DELETE CASCADE;
ALTER TABLE supplier_evaluation_scores ADD CONSTRAINT fk_supplier_evaluation_scores_criterion_id FOREIGN KEY (organization_id, criterion_id) REFERENCES supplier_criteria (organization_id, id) ON DELETE RESTRICT;
ALTER TABLE supplier_evaluation_scores ADD CONSTRAINT fk_supplier_evaluation_scores_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE supplier_evaluation_scores ADD CONSTRAINT fk_supplier_evaluation_scores_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE equipment ADD CONSTRAINT fk_equipment_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE equipment ADD CONSTRAINT fk_equipment_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE equipment ADD CONSTRAINT fk_equipment_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE equipment_check_plans ADD CONSTRAINT fk_equipment_check_plans_equipment_id FOREIGN KEY (organization_id, equipment_id) REFERENCES equipment (organization_id, id) ON DELETE CASCADE;
ALTER TABLE equipment_check_plans ADD CONSTRAINT fk_equipment_check_plans_provider_supplier_id FOREIGN KEY (organization_id, provider_supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (provider_supplier_id);
ALTER TABLE equipment_check_plans ADD CONSTRAINT fk_equipment_check_plans_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE equipment_check_plans ADD CONSTRAINT fk_equipment_check_plans_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE equipment_checks ADD CONSTRAINT fk_equipment_checks_equipment_id FOREIGN KEY (organization_id, equipment_id) REFERENCES equipment (organization_id, id) ON DELETE CASCADE;
ALTER TABLE equipment_checks ADD CONSTRAINT fk_equipment_checks_plan_id FOREIGN KEY (organization_id, plan_id) REFERENCES equipment_check_plans (organization_id, id) ON DELETE SET NULL (plan_id);
ALTER TABLE equipment_checks ADD CONSTRAINT fk_equipment_checks_provider_supplier_id FOREIGN KEY (organization_id, provider_supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (provider_supplier_id);
ALTER TABLE equipment_checks ADD CONSTRAINT fk_equipment_checks_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE equipment_checks ADD CONSTRAINT fk_equipment_checks_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE equipment_check_reservations ADD CONSTRAINT fk_equipment_check_reservations_check_id FOREIGN KEY (organization_id, check_id) REFERENCES equipment_checks (organization_id, id) ON DELETE CASCADE;
ALTER TABLE equipment_check_reservations ADD CONSTRAINT fk_equipment_check_reservations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE equipment_check_reservations ADD CONSTRAINT fk_equipment_check_reservations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE control_plans ADD CONSTRAINT fk_control_plans_process_id FOREIGN KEY (organization_id, process_id) REFERENCES processes (organization_id, id) ON DELETE SET NULL (process_id);
ALTER TABLE control_plans ADD CONSTRAINT fk_control_plans_document_id FOREIGN KEY (organization_id, document_id) REFERENCES documents (organization_id, id) ON DELETE SET NULL (document_id);
ALTER TABLE control_plans ADD CONSTRAINT fk_control_plans_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE control_plans ADD CONSTRAINT fk_control_plans_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE control_points ADD CONSTRAINT fk_control_points_plan_id FOREIGN KEY (organization_id, plan_id) REFERENCES control_plans (organization_id, id) ON DELETE CASCADE;
ALTER TABLE control_points ADD CONSTRAINT fk_control_points_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE control_points ADD CONSTRAINT fk_control_points_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE inspections ADD CONSTRAINT fk_inspections_control_plan_id FOREIGN KEY (organization_id, control_plan_id) REFERENCES control_plans (organization_id, id) ON DELETE SET NULL (control_plan_id);
ALTER TABLE inspections ADD CONSTRAINT fk_inspections_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE inspections ADD CONSTRAINT fk_inspections_project_id FOREIGN KEY (organization_id, project_id) REFERENCES projects (organization_id, id) ON DELETE SET NULL (project_id);
ALTER TABLE inspections ADD CONSTRAINT fk_inspections_supplier_id FOREIGN KEY (organization_id, supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (supplier_id);
ALTER TABLE inspections ADD CONSTRAINT fk_inspections_inspector_membership_id FOREIGN KEY (organization_id, inspector_membership_id) REFERENCES org_memberships (organization_id, id) ON DELETE SET NULL (inspector_membership_id);
ALTER TABLE inspections ADD CONSTRAINT fk_inspections_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE inspections ADD CONSTRAINT fk_inspections_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE inspection_results ADD CONSTRAINT fk_inspection_results_inspection_id FOREIGN KEY (organization_id, inspection_id) REFERENCES inspections (organization_id, id) ON DELETE CASCADE;
ALTER TABLE inspection_results ADD CONSTRAINT fk_inspection_results_control_point_id FOREIGN KEY (organization_id, control_point_id) REFERENCES control_points (organization_id, id) ON DELETE SET NULL (control_point_id);
ALTER TABLE inspection_results ADD CONSTRAINT fk_inspection_results_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE inspection_results ADD CONSTRAINT fk_inspection_results_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE waste_records ADD CONSTRAINT fk_waste_records_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE waste_records ADD CONSTRAINT fk_waste_records_handler_supplier_id FOREIGN KEY (organization_id, handler_supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (handler_supplier_id);
ALTER TABLE waste_records ADD CONSTRAINT fk_waste_records_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE waste_records ADD CONSTRAINT fk_waste_records_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE consumption_records ADD CONSTRAINT fk_consumption_records_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE consumption_records ADD CONSTRAINT fk_consumption_records_equipment_id FOREIGN KEY (organization_id, equipment_id) REFERENCES equipment (organization_id, id) ON DELETE SET NULL (equipment_id);
ALTER TABLE consumption_records ADD CONSTRAINT fk_consumption_records_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE consumption_records ADD CONSTRAINT fk_consumption_records_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;
ALTER TABLE environmental_measurements ADD CONSTRAINT fk_environmental_measurements_site_id FOREIGN KEY (organization_id, site_id) REFERENCES sites (organization_id, id) ON DELETE SET NULL (site_id);
ALTER TABLE environmental_measurements ADD CONSTRAINT fk_environmental_measurements_lab_supplier_id FOREIGN KEY (organization_id, lab_supplier_id) REFERENCES suppliers (organization_id, id) ON DELETE SET NULL (lab_supplier_id);
ALTER TABLE environmental_measurements ADD CONSTRAINT fk_environmental_measurements_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE environmental_measurements ADD CONSTRAINT fk_environmental_measurements_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE;

-- ================================================================== indexes
CREATE INDEX ix_firms_logo_file_id ON firms (logo_file_id);
CREATE INDEX ix_firms_created_by ON firms (created_by);
CREATE INDEX ix_organizations_firm_id ON organizations (firm_id);
CREATE INDEX ix_organizations_sector_id ON organizations (sector_id);
CREATE INDEX ix_organizations_logo_file_id ON organizations (logo_file_id);
CREATE INDEX ix_organizations_created_by ON organizations (created_by);
CREATE INDEX ix_sites_parent_site_id ON sites (parent_site_id);
CREATE INDEX ix_sites_created_by ON sites (created_by);
CREATE INDEX ix_firm_members_firm_id ON firm_members (firm_id);
CREATE INDEX ix_firm_members_user_id ON firm_members (user_id);
CREATE INDEX ix_firm_members_created_by ON firm_members (created_by);
CREATE INDEX ix_org_memberships_user_id ON org_memberships (user_id);
CREATE INDEX ix_org_memberships_invited_by ON org_memberships (invited_by);
CREATE INDEX ix_org_memberships_created_by ON org_memberships (created_by);
CREATE INDEX ix_roles_firm_id ON roles (firm_id);
CREATE INDEX ix_roles_org_id ON roles (org_id);
CREATE INDEX ix_roles_created_by ON roles (created_by);
CREATE INDEX ix_role_permissions_permission_id ON role_permissions (permission_id);
CREATE INDEX ix_role_permissions_created_by ON role_permissions (created_by);
CREATE INDEX ix_membership_roles_membership_id ON membership_roles (membership_id);
CREATE INDEX ix_membership_roles_role_id ON membership_roles (role_id);
CREATE INDEX ix_membership_roles_process_id ON membership_roles (process_id);
CREATE INDEX ix_membership_roles_created_by ON membership_roles (created_by);
CREATE INDEX ix_subscriptions_engagement_id ON subscriptions (engagement_id);
CREATE INDEX ix_subscriptions_created_by ON subscriptions (created_by);
CREATE INDEX ix_consultant_assignments_firm_member_id ON consultant_assignments (firm_member_id);
CREATE INDEX ix_consultant_assignments_created_by ON consultant_assignments (created_by);
CREATE INDEX ix_invitations_firm_id ON invitations (firm_id);
CREATE INDEX ix_invitations_target_org_id ON invitations (target_org_id);
CREATE INDEX ix_invitations_role_id ON invitations (role_id);
CREATE INDEX ix_invitations_invited_by ON invitations (invited_by);
CREATE INDEX ix_invitations_created_by ON invitations (created_by);
CREATE INDEX ix_files_firm_id ON files (firm_id);
CREATE INDEX ix_files_org_id ON files (org_id);
CREATE INDEX ix_files_created_by ON files (created_by);
CREATE INDEX ix_attachments_file_id ON attachments (file_id);
CREATE INDEX ix_attachments_created_by ON attachments (created_by);
CREATE INDEX ix_comments_parent_id ON comments (parent_id);
CREATE INDEX ix_comments_created_by ON comments (created_by);
CREATE INDEX ix_notifications_user_id ON notifications (user_id);
CREATE INDEX ix_notifications_org_id ON notifications (org_id);
CREATE INDEX ix_notification_preferences_user_id ON notification_preferences (user_id);
CREATE INDEX ix_activity_log_firm_id ON activity_log (firm_id);
CREATE INDEX ix_activity_log_org_id ON activity_log (org_id);
CREATE INDEX ix_activity_log_actor_user_id ON activity_log (actor_user_id);
CREATE INDEX ix_import_jobs_file_id ON import_jobs (file_id);
CREATE INDEX ix_import_jobs_created_by ON import_jobs (created_by);
CREATE INDEX ix_export_jobs_document_template_id ON export_jobs (document_template_id);
CREATE INDEX ix_export_jobs_file_id ON export_jobs (file_id);
CREATE INDEX ix_export_jobs_created_by ON export_jobs (created_by);
CREATE INDEX ix_sectors_firm_id ON sectors (firm_id);
CREATE INDEX ix_sectors_created_by ON sectors (created_by);
CREATE INDEX ix_standards_created_by ON standards (created_by);
CREATE INDEX ix_standard_editions_standard_id ON standard_editions (standard_id);
CREATE INDEX ix_standard_editions_created_by ON standard_editions (created_by);
CREATE INDEX ix_clauses_edition_id ON clauses (edition_id);
CREATE INDEX ix_clauses_parent_id ON clauses (parent_id);
CREATE INDEX ix_clauses_created_by ON clauses (created_by);
CREATE INDEX ix_clause_correspondences_from_clause_id ON clause_correspondences (from_clause_id);
CREATE INDEX ix_clause_correspondences_to_clause_id ON clause_correspondences (to_clause_id);
CREATE INDEX ix_clause_correspondences_created_by ON clause_correspondences (created_by);
CREATE INDEX ix_regulatory_texts_firm_id ON regulatory_texts (firm_id);
CREATE INDEX ix_regulatory_texts_amended_by_id ON regulatory_texts (amended_by_id);
CREATE INDEX ix_regulatory_texts_created_by ON regulatory_texts (created_by);
CREATE INDEX ix_regulatory_requirements_text_id ON regulatory_requirements (text_id);
CREATE INDEX ix_regulatory_requirements_created_by ON regulatory_requirements (created_by);
CREATE INDEX ix_substance_compatibility_rules_created_by ON substance_compatibility_rules (created_by);
CREATE INDEX ix_scoring_models_firm_id ON scoring_models (firm_id);
CREATE INDEX ix_scoring_models_org_id ON scoring_models (org_id);
CREATE INDEX ix_scoring_models_created_by ON scoring_models (created_by);
CREATE INDEX ix_scoring_dimensions_model_id ON scoring_dimensions (model_id);
CREATE INDEX ix_scoring_dimensions_created_by ON scoring_dimensions (created_by);
CREATE INDEX ix_scoring_levels_dimension_id ON scoring_levels (dimension_id);
CREATE INDEX ix_scoring_levels_created_by ON scoring_levels (created_by);
CREATE INDEX ix_scoring_bands_model_id ON scoring_bands (model_id);
CREATE INDEX ix_scoring_bands_created_by ON scoring_bands (created_by);
CREATE INDEX ix_kits_firm_id ON kits (firm_id);
CREATE INDEX ix_kits_sector_id ON kits (sector_id);
CREATE INDEX ix_kits_created_by ON kits (created_by);
CREATE INDEX ix_kit_editions_edition_id ON kit_editions (edition_id);
CREATE INDEX ix_kit_editions_created_by ON kit_editions (created_by);
CREATE INDEX ix_kit_items_kit_id ON kit_items (kit_id);
CREATE INDEX ix_kit_items_created_by ON kit_items (created_by);
CREATE INDEX ix_document_templates_firm_id ON document_templates (firm_id);
CREATE INDEX ix_document_templates_file_id ON document_templates (file_id);
CREATE INDEX ix_document_templates_created_by ON document_templates (created_by);
CREATE INDEX ix_template_clauses_clause_id ON template_clauses (clause_id);
CREATE INDEX ix_template_clauses_created_by ON template_clauses (created_by);
CREATE INDEX ix_process_templates_firm_id ON process_templates (firm_id);
CREATE INDEX ix_process_templates_sector_id ON process_templates (sector_id);
CREATE INDEX ix_process_templates_created_by ON process_templates (created_by);
CREATE INDEX ix_indicator_templates_firm_id ON indicator_templates (firm_id);
CREATE INDEX ix_indicator_templates_process_template_id ON indicator_templates (process_template_id);
CREATE INDEX ix_indicator_templates_created_by ON indicator_templates (created_by);
CREATE INDEX ix_risk_templates_firm_id ON risk_templates (firm_id);
CREATE INDEX ix_risk_templates_sector_id ON risk_templates (sector_id);
CREATE INDEX ix_risk_templates_created_by ON risk_templates (created_by);
CREATE INDEX ix_clause_evidence_expectations_firm_id ON clause_evidence_expectations (firm_id);
CREATE INDEX ix_clause_evidence_expectations_clause_id ON clause_evidence_expectations (clause_id);
CREATE INDEX ix_clause_evidence_expectations_document_template_id ON clause_evidence_expectations (document_template_id);
CREATE INDEX ix_clause_evidence_expectations_created_by ON clause_evidence_expectations (created_by);
CREATE INDEX ix_certification_bodies_firm_id ON certification_bodies (firm_id);
CREATE INDEX ix_certification_bodies_created_by ON certification_bodies (created_by);
CREATE INDEX ix_engagements_kit_id ON engagements (kit_id);
CREATE INDEX ix_engagements_lead_consultant_id ON engagements (lead_consultant_id);
CREATE INDEX ix_engagements_certification_body_id ON engagements (certification_body_id);
CREATE INDEX ix_engagements_created_by ON engagements (created_by);
CREATE INDEX ix_engagement_editions_organization_id ON engagement_editions (organization_id);
CREATE INDEX ix_engagement_editions_edition_id ON engagement_editions (edition_id);
CREATE INDEX ix_engagement_editions_created_by ON engagement_editions (created_by);
CREATE INDEX ix_engagement_milestones_engagement_id ON engagement_milestones (engagement_id);
CREATE INDEX ix_engagement_milestones_created_by ON engagement_milestones (created_by);
CREATE INDEX ix_deliverables_engagement_id ON deliverables (engagement_id);
CREATE INDEX ix_deliverables_milestone_id ON deliverables (milestone_id);
CREATE INDEX ix_deliverables_document_id ON deliverables (document_id);
CREATE INDEX ix_deliverables_owner_id ON deliverables (owner_id);
CREATE INDEX ix_deliverables_created_by ON deliverables (created_by);
CREATE INDEX ix_consultant_visits_engagement_id ON consultant_visits (engagement_id);
CREATE INDEX ix_consultant_visits_firm_member_id ON consultant_visits (firm_member_id);
CREATE INDEX ix_consultant_visits_created_by ON consultant_visits (created_by);
CREATE INDEX ix_gap_assessments_engagement_id ON gap_assessments (engagement_id);
CREATE INDEX ix_gap_assessments_edition_id ON gap_assessments (edition_id);
CREATE INDEX ix_gap_assessments_assessor_id ON gap_assessments (assessor_id);
CREATE INDEX ix_gap_assessments_created_by ON gap_assessments (created_by);
CREATE INDEX ix_gap_assessment_items_gap_assessment_id ON gap_assessment_items (gap_assessment_id);
CREATE INDEX ix_gap_assessment_items_clause_id ON gap_assessment_items (clause_id);
CREATE INDEX ix_gap_assessment_items_created_by ON gap_assessment_items (created_by);
CREATE INDEX ix_readiness_snapshots_edition_id ON readiness_snapshots (edition_id);
CREATE INDEX ix_certificates_edition_id ON certificates (edition_id);
CREATE INDEX ix_certificates_certification_body_id ON certificates (certification_body_id);
CREATE INDEX ix_certificates_created_by ON certificates (created_by);
CREATE INDEX ix_management_systems_document_id ON management_systems (document_id);
CREATE INDEX ix_management_systems_created_by ON management_systems (created_by);
CREATE INDEX ix_management_system_editions_organization_id ON management_system_editions (organization_id);
CREATE INDEX ix_management_system_editions_edition_id ON management_system_editions (edition_id);
CREATE INDEX ix_management_system_editions_created_by ON management_system_editions (created_by);
CREATE INDEX ix_clause_exclusions_management_system_id ON clause_exclusions (management_system_id);
CREATE INDEX ix_clause_exclusions_clause_id ON clause_exclusions (clause_id);
CREATE INDEX ix_clause_exclusions_created_by ON clause_exclusions (created_by);
CREATE INDEX ix_context_issues_process_id ON context_issues (process_id);
CREATE INDEX ix_context_issues_created_by ON context_issues (created_by);
CREATE INDEX ix_interested_parties_created_by ON interested_parties (created_by);
CREATE INDEX ix_party_requirements_party_id ON party_requirements (party_id);
CREATE INDEX ix_party_requirements_process_id ON party_requirements (process_id);
CREATE INDEX ix_party_requirements_created_by ON party_requirements (created_by);
CREATE INDEX ix_policy_axes_policy_document_id ON policy_axes (policy_document_id);
CREATE INDEX ix_policy_axes_created_by ON policy_axes (created_by);
CREATE INDEX ix_processes_parent_id ON processes (parent_id);
CREATE INDEX ix_processes_owner_membership_id ON processes (owner_membership_id);
CREATE INDEX ix_processes_deputy_membership_id ON processes (deputy_membership_id);
CREATE INDEX ix_processes_sheet_document_id ON processes (sheet_document_id);
CREATE INDEX ix_processes_template_id ON processes (template_id);
CREATE INDEX ix_processes_created_by ON processes (created_by);
CREATE INDEX ix_process_steps_process_id ON process_steps (process_id);
CREATE INDEX ix_process_steps_responsible_position_id ON process_steps (responsible_position_id);
CREATE INDEX ix_process_steps_created_by ON process_steps (created_by);
CREATE INDEX ix_process_step_documents_organization_id ON process_step_documents (organization_id);
CREATE INDEX ix_process_step_documents_document_id ON process_step_documents (document_id);
CREATE INDEX ix_process_step_documents_created_by ON process_step_documents (created_by);
CREATE INDEX ix_process_interactions_from_process_id ON process_interactions (from_process_id);
CREATE INDEX ix_process_interactions_to_process_id ON process_interactions (to_process_id);
CREATE INDEX ix_process_interactions_created_by ON process_interactions (created_by);
CREATE INDEX ix_process_clauses_organization_id ON process_clauses (organization_id);
CREATE INDEX ix_process_clauses_clause_id ON process_clauses (clause_id);
CREATE INDEX ix_process_clauses_created_by ON process_clauses (created_by);
CREATE INDEX ix_process_reviews_process_id ON process_reviews (process_id);
CREATE INDEX ix_process_reviews_reviewer_membership_id ON process_reviews (reviewer_membership_id);
CREATE INDEX ix_process_reviews_created_by ON process_reviews (created_by);
CREATE INDEX ix_document_types_created_by ON document_types (created_by);
CREATE INDEX ix_documents_document_type_id ON documents (document_type_id);
CREATE INDEX ix_documents_process_id ON documents (process_id);
CREATE INDEX ix_documents_owner_membership_id ON documents (owner_membership_id);
CREATE INDEX ix_documents_current_version_id ON documents (current_version_id);
CREATE INDEX ix_documents_template_id ON documents (template_id);
CREATE INDEX ix_documents_created_by ON documents (created_by);
CREATE INDEX ix_document_versions_document_id ON document_versions (document_id);
CREATE INDEX ix_document_versions_file_id ON document_versions (file_id);
CREATE INDEX ix_document_versions_created_by ON document_versions (created_by);
CREATE INDEX ix_document_approvals_version_id ON document_approvals (version_id);
CREATE INDEX ix_document_approvals_assignee_membership_id ON document_approvals (assignee_membership_id);
CREATE INDEX ix_document_approvals_assignee_firm_member_id ON document_approvals (assignee_firm_member_id);
CREATE INDEX ix_document_approvals_created_by ON document_approvals (created_by);
CREATE INDEX ix_distribution_points_created_by ON distribution_points (created_by);
CREATE INDEX ix_document_distributions_version_id ON document_distributions (version_id);
CREATE INDEX ix_document_distributions_distribution_point_id ON document_distributions (distribution_point_id);
CREATE INDEX ix_document_distributions_created_by ON document_distributions (created_by);
CREATE INDEX ix_document_acknowledgements_version_id ON document_acknowledgements (version_id);
CREATE INDEX ix_document_acknowledgements_membership_id ON document_acknowledgements (membership_id);
CREATE INDEX ix_document_acknowledgements_employee_id ON document_acknowledgements (employee_id);
CREATE INDEX ix_document_acknowledgements_created_by ON document_acknowledgements (created_by);
CREATE INDEX ix_document_clauses_organization_id ON document_clauses (organization_id);
CREATE INDEX ix_document_clauses_clause_id ON document_clauses (clause_id);
CREATE INDEX ix_document_clauses_created_by ON document_clauses (created_by);
CREATE INDEX ix_document_sequences_document_type_id ON document_sequences (document_type_id);
CREATE INDEX ix_document_sequences_process_id ON document_sequences (process_id);
CREATE INDEX ix_document_sequences_created_by ON document_sequences (created_by);
CREATE INDEX ix_register_definitions_firm_id ON register_definitions (firm_id);
CREATE INDEX ix_register_definitions_org_id ON register_definitions (org_id);
CREATE INDEX ix_register_definitions_document_id ON register_definitions (document_id);
CREATE INDEX ix_register_definitions_process_id ON register_definitions (process_id);
CREATE INDEX ix_register_definitions_created_by ON register_definitions (created_by);
CREATE INDEX ix_register_entries_definition_id ON register_entries (definition_id);
CREATE INDEX ix_register_entries_site_id ON register_entries (site_id);
CREATE INDEX ix_register_entries_process_id ON register_entries (process_id);
CREATE INDEX ix_register_entries_project_id ON register_entries (project_id);
CREATE INDEX ix_register_entries_created_by ON register_entries (created_by);
CREATE INDEX ix_change_requests_requested_by ON change_requests (requested_by);
CREATE INDEX ix_change_requests_approved_by ON change_requests (approved_by);
CREATE INDEX ix_change_requests_created_by ON change_requests (created_by);
CREATE INDEX ix_change_impacts_change_request_id ON change_impacts (change_request_id);
CREATE INDEX ix_change_impacts_created_by ON change_impacts (created_by);
CREATE INDEX ix_knowledge_items_process_id ON knowledge_items (process_id);
CREATE INDEX ix_knowledge_items_holder_employee_id ON knowledge_items (holder_employee_id);
CREATE INDEX ix_knowledge_items_document_id ON knowledge_items (document_id);
CREATE INDEX ix_knowledge_items_created_by ON knowledge_items (created_by);
CREATE INDEX ix_activities_site_id ON activities (site_id);
CREATE INDEX ix_activities_process_id ON activities (process_id);
CREATE INDEX ix_activities_created_by ON activities (created_by);
CREATE INDEX ix_risk_assessments_scoring_model_id ON risk_assessments (scoring_model_id);
CREATE INDEX ix_risk_assessments_document_id ON risk_assessments (document_id);
CREATE INDEX ix_risk_assessments_created_by ON risk_assessments (created_by);
CREATE INDEX ix_risk_items_assessment_id ON risk_items (assessment_id);
CREATE INDEX ix_risk_items_activity_id ON risk_items (activity_id);
CREATE INDEX ix_risk_items_process_id ON risk_items (process_id);
CREATE INDEX ix_risk_items_context_issue_id ON risk_items (context_issue_id);
CREATE INDEX ix_risk_items_interested_party_id ON risk_items (interested_party_id);
CREATE INDEX ix_risk_items_owner_membership_id ON risk_items (owner_membership_id);
CREATE INDEX ix_risk_items_current_band_id ON risk_items (current_band_id);
CREATE INDEX ix_risk_items_template_id ON risk_items (template_id);
CREATE INDEX ix_risk_items_created_by ON risk_items (created_by);
CREATE INDEX ix_ohs_hazard_details_regulatory_requirement_id ON ohs_hazard_details (regulatory_requirement_id);
CREATE INDEX ix_ohs_hazard_details_created_by ON ohs_hazard_details (created_by);
CREATE INDEX ix_env_aspect_details_regulatory_requirement_id ON env_aspect_details (regulatory_requirement_id);
CREATE INDEX ix_env_aspect_details_created_by ON env_aspect_details (created_by);
CREATE INDEX ix_risk_evaluations_risk_item_id ON risk_evaluations (risk_item_id);
CREATE INDEX ix_risk_evaluations_evaluator_membership_id ON risk_evaluations (evaluator_membership_id);
CREATE INDEX ix_risk_evaluations_band_id ON risk_evaluations (band_id);
CREATE INDEX ix_risk_evaluations_created_by ON risk_evaluations (created_by);
CREATE INDEX ix_risk_evaluation_scores_organization_id ON risk_evaluation_scores (organization_id);
CREATE INDEX ix_risk_evaluation_scores_dimension_id ON risk_evaluation_scores (dimension_id);
CREATE INDEX ix_risk_evaluation_scores_created_by ON risk_evaluation_scores (created_by);
CREATE INDEX ix_emergency_situations_site_id ON emergency_situations (site_id);
CREATE INDEX ix_emergency_situations_risk_item_id ON emergency_situations (risk_item_id);
CREATE INDEX ix_emergency_situations_response_document_id ON emergency_situations (response_document_id);
CREATE INDEX ix_emergency_situations_responsible_membership_id ON emergency_situations (responsible_membership_id);
CREATE INDEX ix_emergency_situations_created_by ON emergency_situations (created_by);
CREATE INDEX ix_emergency_drills_emergency_situation_id ON emergency_drills (emergency_situation_id);
CREATE INDEX ix_emergency_drills_site_id ON emergency_drills (site_id);
CREATE INDEX ix_emergency_drills_created_by ON emergency_drills (created_by);
CREATE INDEX ix_hazardous_substances_site_id ON hazardous_substances (site_id);
CREATE INDEX ix_hazardous_substances_supplier_id ON hazardous_substances (supplier_id);
CREATE INDEX ix_hazardous_substances_sds_file_id ON hazardous_substances (sds_file_id);
CREATE INDEX ix_hazardous_substances_created_by ON hazardous_substances (created_by);
CREATE INDEX ix_compliance_obligations_regulatory_text_id ON compliance_obligations (regulatory_text_id);
CREATE INDEX ix_compliance_obligations_regulatory_requirement_id ON compliance_obligations (regulatory_requirement_id);
CREATE INDEX ix_compliance_obligations_party_requirement_id ON compliance_obligations (party_requirement_id);
CREATE INDEX ix_compliance_obligations_owner_membership_id ON compliance_obligations (owner_membership_id);
CREATE INDEX ix_compliance_obligations_process_id ON compliance_obligations (process_id);
CREATE INDEX ix_compliance_obligations_created_by ON compliance_obligations (created_by);
CREATE INDEX ix_compliance_evaluations_obligation_id ON compliance_evaluations (obligation_id);
CREATE INDEX ix_compliance_evaluations_evaluator_membership_id ON compliance_evaluations (evaluator_membership_id);
CREATE INDEX ix_compliance_evaluations_evaluator_firm_member_id ON compliance_evaluations (evaluator_firm_member_id);
CREATE INDEX ix_compliance_evaluations_created_by ON compliance_evaluations (created_by);
CREATE INDEX ix_objectives_policy_axis_id ON objectives (policy_axis_id);
CREATE INDEX ix_objectives_process_id ON objectives (process_id);
CREATE INDEX ix_objectives_owner_membership_id ON objectives (owner_membership_id);
CREATE INDEX ix_objectives_created_by ON objectives (created_by);
CREATE INDEX ix_indicators_process_id ON indicators (process_id);
CREATE INDEX ix_indicators_objective_id ON indicators (objective_id);
CREATE INDEX ix_indicators_owner_membership_id ON indicators (owner_membership_id);
CREATE INDEX ix_indicators_template_id ON indicators (template_id);
CREATE INDEX ix_indicators_created_by ON indicators (created_by);
CREATE INDEX ix_indicator_measurements_indicator_id ON indicator_measurements (indicator_id);
CREATE INDEX ix_indicator_measurements_entered_by_membership_id ON indicator_measurements (entered_by_membership_id);
CREATE INDEX ix_indicator_measurements_created_by ON indicator_measurements (created_by);
CREATE INDEX ix_customers_created_by ON customers (created_by);
CREATE INDEX ix_projects_customer_id ON projects (customer_id);
CREATE INDEX ix_projects_site_id ON projects (site_id);
CREATE INDEX ix_projects_manager_membership_id ON projects (manager_membership_id);
CREATE INDEX ix_projects_created_by ON projects (created_by);
CREATE INDEX ix_customer_surveys_customer_id ON customer_surveys (customer_id);
CREATE INDEX ix_customer_surveys_project_id ON customer_surveys (project_id);
CREATE INDEX ix_customer_surveys_created_by ON customer_surveys (created_by);
CREATE INDEX ix_complaints_customer_id ON complaints (customer_id);
CREATE INDEX ix_complaints_project_id ON complaints (project_id);
CREATE INDEX ix_complaints_created_by ON complaints (created_by);
CREATE INDEX ix_incidents_site_id ON incidents (site_id);
CREATE INDEX ix_incidents_project_id ON incidents (project_id);
CREATE INDEX ix_incidents_employee_id ON incidents (employee_id);
CREATE INDEX ix_incidents_reported_by_membership_id ON incidents (reported_by_membership_id);
CREATE INDEX ix_incidents_created_by ON incidents (created_by);
CREATE INDEX ix_nonconformities_process_id ON nonconformities (process_id);
CREATE INDEX ix_nonconformities_site_id ON nonconformities (site_id);
CREATE INDEX ix_nonconformities_project_id ON nonconformities (project_id);
CREATE INDEX ix_nonconformities_supplier_id ON nonconformities (supplier_id);
CREATE INDEX ix_nonconformities_detected_by_membership_id ON nonconformities (detected_by_membership_id);
CREATE INDEX ix_nonconformities_detected_by_firm_member_id ON nonconformities (detected_by_firm_member_id);
CREATE INDEX ix_nonconformities_owner_membership_id ON nonconformities (owner_membership_id);
CREATE INDEX ix_nonconformities_audit_finding_id ON nonconformities (audit_finding_id);
CREATE INDEX ix_nonconformities_gap_assessment_item_id ON nonconformities (gap_assessment_item_id);
CREATE INDEX ix_nonconformities_indicator_measurement_id ON nonconformities (indicator_measurement_id);
CREATE INDEX ix_nonconformities_complaint_id ON nonconformities (complaint_id);
CREATE INDEX ix_nonconformities_incident_id ON nonconformities (incident_id);
CREATE INDEX ix_nonconformities_emergency_drill_id ON nonconformities (emergency_drill_id);
CREATE INDEX ix_nonconformities_compliance_evaluation_id ON nonconformities (compliance_evaluation_id);
CREATE INDEX ix_nonconformities_inspection_result_id ON nonconformities (inspection_result_id);
CREATE INDEX ix_nonconformities_management_review_id ON nonconformities (management_review_id);
CREATE INDEX ix_nonconformities_worker_meeting_id ON nonconformities (worker_meeting_id);
CREATE INDEX ix_nonconformities_register_entry_id ON nonconformities (register_entry_id);
CREATE INDEX ix_nonconformities_created_by ON nonconformities (created_by);
CREATE INDEX ix_nonconformity_clauses_organization_id ON nonconformity_clauses (organization_id);
CREATE INDEX ix_nonconformity_clauses_clause_id ON nonconformity_clauses (clause_id);
CREATE INDEX ix_nonconformity_clauses_created_by ON nonconformity_clauses (created_by);
CREATE INDEX ix_actions_efficacy_verified_by ON actions (efficacy_verified_by);
CREATE INDEX ix_actions_nonconformity_id ON actions (nonconformity_id);
CREATE INDEX ix_actions_risk_item_id ON actions (risk_item_id);
CREATE INDEX ix_actions_objective_id ON actions (objective_id);
CREATE INDEX ix_actions_audit_finding_id ON actions (audit_finding_id);
CREATE INDEX ix_actions_management_review_decision_id ON actions (management_review_decision_id);
CREATE INDEX ix_actions_gap_assessment_item_id ON actions (gap_assessment_item_id);
CREATE INDEX ix_actions_compliance_evaluation_id ON actions (compliance_evaluation_id);
CREATE INDEX ix_actions_change_request_id ON actions (change_request_id);
CREATE INDEX ix_actions_worker_meeting_id ON actions (worker_meeting_id);
CREATE INDEX ix_actions_emergency_drill_id ON actions (emergency_drill_id);
CREATE INDEX ix_actions_equipment_check_id ON actions (equipment_check_id);
CREATE INDEX ix_actions_inspection_id ON actions (inspection_id);
CREATE INDEX ix_actions_created_by ON actions (created_by);
CREATE INDEX ix_action_owners_organization_id ON action_owners (organization_id);
CREATE INDEX ix_action_owners_membership_id ON action_owners (membership_id);
CREATE INDEX ix_action_owners_created_by ON action_owners (created_by);
CREATE INDEX ix_action_updates_action_id ON action_updates (action_id);
CREATE INDEX ix_action_updates_created_by ON action_updates (created_by);
CREATE INDEX ix_audit_programs_document_id ON audit_programs (document_id);
CREATE INDEX ix_audit_programs_approved_by ON audit_programs (approved_by);
CREATE INDEX ix_audit_programs_created_by ON audit_programs (created_by);
CREATE INDEX ix_audit_program_items_program_id ON audit_program_items (program_id);
CREATE INDEX ix_audit_program_items_process_id ON audit_program_items (process_id);
CREATE INDEX ix_audit_program_items_audit_id ON audit_program_items (audit_id);
CREATE INDEX ix_audit_program_items_created_by ON audit_program_items (created_by);
CREATE INDEX ix_audits_supplier_id ON audits (supplier_id);
CREATE INDEX ix_audits_certification_body_id ON audits (certification_body_id);
CREATE INDEX ix_audits_engagement_id ON audits (engagement_id);
CREATE INDEX ix_audits_report_document_id ON audits (report_document_id);
CREATE INDEX ix_audits_created_by ON audits (created_by);
CREATE INDEX ix_audit_editions_organization_id ON audit_editions (organization_id);
CREATE INDEX ix_audit_editions_edition_id ON audit_editions (edition_id);
CREATE INDEX ix_audit_editions_created_by ON audit_editions (created_by);
CREATE INDEX ix_audit_team_members_audit_id ON audit_team_members (audit_id);
CREATE INDEX ix_audit_team_members_membership_id ON audit_team_members (membership_id);
CREATE INDEX ix_audit_team_members_firm_member_id ON audit_team_members (firm_member_id);
CREATE INDEX ix_audit_team_members_created_by ON audit_team_members (created_by);
CREATE INDEX ix_audit_plan_slots_audit_id ON audit_plan_slots (audit_id);
CREATE INDEX ix_audit_plan_slots_process_id ON audit_plan_slots (process_id);
CREATE INDEX ix_audit_plan_slots_site_id ON audit_plan_slots (site_id);
CREATE INDEX ix_audit_plan_slots_team_member_id ON audit_plan_slots (team_member_id);
CREATE INDEX ix_audit_plan_slots_created_by ON audit_plan_slots (created_by);
CREATE INDEX ix_audit_checklist_items_audit_id ON audit_checklist_items (audit_id);
CREATE INDEX ix_audit_checklist_items_clause_id ON audit_checklist_items (clause_id);
CREATE INDEX ix_audit_checklist_items_process_id ON audit_checklist_items (process_id);
CREATE INDEX ix_audit_checklist_items_created_by ON audit_checklist_items (created_by);
CREATE INDEX ix_audit_findings_audit_id ON audit_findings (audit_id);
CREATE INDEX ix_audit_findings_clause_id ON audit_findings (clause_id);
CREATE INDEX ix_audit_findings_process_id ON audit_findings (process_id);
CREATE INDEX ix_audit_findings_site_id ON audit_findings (site_id);
CREATE INDEX ix_audit_findings_created_by ON audit_findings (created_by);
CREATE INDEX ix_management_reviews_chair_membership_id ON management_reviews (chair_membership_id);
CREATE INDEX ix_management_reviews_minutes_document_id ON management_reviews (minutes_document_id);
CREATE INDEX ix_management_reviews_created_by ON management_reviews (created_by);
CREATE INDEX ix_management_review_participants_review_id ON management_review_participants (review_id);
CREATE INDEX ix_management_review_participants_membership_id ON management_review_participants (membership_id);
CREATE INDEX ix_management_review_participants_firm_member_id ON management_review_participants (firm_member_id);
CREATE INDEX ix_management_review_participants_created_by ON management_review_participants (created_by);
CREATE INDEX ix_management_review_inputs_review_id ON management_review_inputs (review_id);
CREATE INDEX ix_management_review_inputs_prepared_by ON management_review_inputs (prepared_by);
CREATE INDEX ix_management_review_inputs_created_by ON management_review_inputs (created_by);
CREATE INDEX ix_management_review_decisions_review_id ON management_review_decisions (review_id);
CREATE INDEX ix_management_review_decisions_owner_membership_id ON management_review_decisions (owner_membership_id);
CREATE INDEX ix_management_review_decisions_created_by ON management_review_decisions (created_by);
CREATE INDEX ix_positions_process_id ON positions (process_id);
CREATE INDEX ix_positions_reports_to_id ON positions (reports_to_id);
CREATE INDEX ix_positions_document_id ON positions (document_id);
CREATE INDEX ix_positions_created_by ON positions (created_by);
CREATE INDEX ix_employees_position_id ON employees (position_id);
CREATE INDEX ix_employees_site_id ON employees (site_id);
CREATE INDEX ix_employees_created_by ON employees (created_by);
CREATE INDEX ix_competencies_created_by ON competencies (created_by);
CREATE INDEX ix_position_competencies_organization_id ON position_competencies (organization_id);
CREATE INDEX ix_position_competencies_competency_id ON position_competencies (competency_id);
CREATE INDEX ix_position_competencies_created_by ON position_competencies (created_by);
CREATE INDEX ix_competency_evaluations_employee_id ON competency_evaluations (employee_id);
CREATE INDEX ix_competency_evaluations_competency_id ON competency_evaluations (competency_id);
CREATE INDEX ix_competency_evaluations_evaluator_membership_id ON competency_evaluations (evaluator_membership_id);
CREATE INDEX ix_competency_evaluations_created_by ON competency_evaluations (created_by);
CREATE INDEX ix_employee_qualifications_employee_id ON employee_qualifications (employee_id);
CREATE INDEX ix_employee_qualifications_competency_id ON employee_qualifications (competency_id);
CREATE INDEX ix_employee_qualifications_issuer_supplier_id ON employee_qualifications (issuer_supplier_id);
CREATE INDEX ix_employee_qualifications_created_by ON employee_qualifications (created_by);
CREATE INDEX ix_training_needs_employee_id ON training_needs (employee_id);
CREATE INDEX ix_training_needs_position_id ON training_needs (position_id);
CREATE INDEX ix_training_needs_competency_id ON training_needs (competency_id);
CREATE INDEX ix_training_needs_created_by ON training_needs (created_by);
CREATE INDEX ix_training_plans_document_id ON training_plans (document_id);
CREATE INDEX ix_training_plans_created_by ON training_plans (created_by);
CREATE INDEX ix_training_sessions_plan_id ON training_sessions (plan_id);
CREATE INDEX ix_training_sessions_need_id ON training_sessions (need_id);
CREATE INDEX ix_training_sessions_competency_id ON training_sessions (competency_id);
CREATE INDEX ix_training_sessions_provider_supplier_id ON training_sessions (provider_supplier_id);
CREATE INDEX ix_training_sessions_site_id ON training_sessions (site_id);
CREATE INDEX ix_training_sessions_created_by ON training_sessions (created_by);
CREATE INDEX ix_training_attendances_organization_id ON training_attendances (organization_id);
CREATE INDEX ix_training_attendances_employee_id ON training_attendances (employee_id);
CREATE INDEX ix_training_attendances_created_by ON training_attendances (created_by);
CREATE INDEX ix_recruitment_requests_position_id ON recruitment_requests (position_id);
CREATE INDEX ix_recruitment_requests_requested_by ON recruitment_requests (requested_by);
CREATE INDEX ix_recruitment_requests_created_by ON recruitment_requests (created_by);
CREATE INDEX ix_onboarding_plans_employee_id ON onboarding_plans (employee_id);
CREATE INDEX ix_onboarding_plans_tutor_employee_id ON onboarding_plans (tutor_employee_id);
CREATE INDEX ix_onboarding_plans_created_by ON onboarding_plans (created_by);
CREATE INDEX ix_medical_visits_employee_id ON medical_visits (employee_id);
CREATE INDEX ix_medical_visits_created_by ON medical_visits (created_by);
CREATE INDEX ix_ppe_issues_employee_id ON ppe_issues (employee_id);
CREATE INDEX ix_ppe_issues_created_by ON ppe_issues (created_by);
CREATE INDEX ix_communication_plan_items_sender_membership_id ON communication_plan_items (sender_membership_id);
CREATE INDEX ix_communication_plan_items_process_id ON communication_plan_items (process_id);
CREATE INDEX ix_communication_plan_items_created_by ON communication_plan_items (created_by);
CREATE INDEX ix_communication_records_plan_item_id ON communication_records (plan_item_id);
CREATE INDEX ix_communication_records_created_by ON communication_records (created_by);
CREATE INDEX ix_worker_meetings_created_by ON worker_meetings (created_by);
CREATE INDEX ix_worker_meeting_participants_organization_id ON worker_meeting_participants (organization_id);
CREATE INDEX ix_worker_meeting_participants_employee_id ON worker_meeting_participants (employee_id);
CREATE INDEX ix_worker_meeting_participants_created_by ON worker_meeting_participants (created_by);
CREATE INDEX ix_visitor_logs_site_id ON visitor_logs (site_id);
CREATE INDEX ix_visitor_logs_host_employee_id ON visitor_logs (host_employee_id);
CREATE INDEX ix_visitor_logs_created_by ON visitor_logs (created_by);
CREATE INDEX ix_suppliers_created_by ON suppliers (created_by);
CREATE INDEX ix_supplier_criteria_created_by ON supplier_criteria (created_by);
CREATE INDEX ix_supplier_evaluations_supplier_id ON supplier_evaluations (supplier_id);
CREATE INDEX ix_supplier_evaluations_evaluator_membership_id ON supplier_evaluations (evaluator_membership_id);
CREATE INDEX ix_supplier_evaluations_created_by ON supplier_evaluations (created_by);
CREATE INDEX ix_supplier_evaluation_scores_organization_id ON supplier_evaluation_scores (organization_id);
CREATE INDEX ix_supplier_evaluation_scores_criterion_id ON supplier_evaluation_scores (criterion_id);
CREATE INDEX ix_supplier_evaluation_scores_created_by ON supplier_evaluation_scores (created_by);
CREATE INDEX ix_equipment_site_id ON equipment (site_id);
CREATE INDEX ix_equipment_created_by ON equipment (created_by);
CREATE INDEX ix_equipment_check_plans_equipment_id ON equipment_check_plans (equipment_id);
CREATE INDEX ix_equipment_check_plans_provider_supplier_id ON equipment_check_plans (provider_supplier_id);
CREATE INDEX ix_equipment_check_plans_created_by ON equipment_check_plans (created_by);
CREATE INDEX ix_equipment_checks_equipment_id ON equipment_checks (equipment_id);
CREATE INDEX ix_equipment_checks_plan_id ON equipment_checks (plan_id);
CREATE INDEX ix_equipment_checks_provider_supplier_id ON equipment_checks (provider_supplier_id);
CREATE INDEX ix_equipment_checks_created_by ON equipment_checks (created_by);
CREATE INDEX ix_equipment_check_reservations_check_id ON equipment_check_reservations (check_id);
CREATE INDEX ix_equipment_check_reservations_created_by ON equipment_check_reservations (created_by);
CREATE INDEX ix_control_plans_process_id ON control_plans (process_id);
CREATE INDEX ix_control_plans_document_id ON control_plans (document_id);
CREATE INDEX ix_control_plans_created_by ON control_plans (created_by);
CREATE INDEX ix_control_points_plan_id ON control_points (plan_id);
CREATE INDEX ix_control_points_created_by ON control_points (created_by);
CREATE INDEX ix_inspections_control_plan_id ON inspections (control_plan_id);
CREATE INDEX ix_inspections_site_id ON inspections (site_id);
CREATE INDEX ix_inspections_project_id ON inspections (project_id);
CREATE INDEX ix_inspections_supplier_id ON inspections (supplier_id);
CREATE INDEX ix_inspections_inspector_membership_id ON inspections (inspector_membership_id);
CREATE INDEX ix_inspections_created_by ON inspections (created_by);
CREATE INDEX ix_inspection_results_inspection_id ON inspection_results (inspection_id);
CREATE INDEX ix_inspection_results_control_point_id ON inspection_results (control_point_id);
CREATE INDEX ix_inspection_results_created_by ON inspection_results (created_by);
CREATE INDEX ix_waste_records_site_id ON waste_records (site_id);
CREATE INDEX ix_waste_records_handler_supplier_id ON waste_records (handler_supplier_id);
CREATE INDEX ix_waste_records_created_by ON waste_records (created_by);
CREATE INDEX ix_consumption_records_site_id ON consumption_records (site_id);
CREATE INDEX ix_consumption_records_equipment_id ON consumption_records (equipment_id);
CREATE INDEX ix_consumption_records_created_by ON consumption_records (created_by);
CREATE INDEX ix_environmental_measurements_site_id ON environmental_measurements (site_id);
CREATE INDEX ix_environmental_measurements_lab_supplier_id ON environmental_measurements (lab_supplier_id);
CREATE INDEX ix_environmental_measurements_created_by ON environmental_measurements (created_by);
CREATE INDEX ix_actions_open_due ON actions (organization_id, due_on) WHERE status IN ('planned','in_progress');
CREATE INDEX ix_nc_open ON nonconformities (organization_id, status) WHERE status <> 'closed';
CREATE INDEX ix_attachments_entity ON attachments (entity_type, entity_id);
CREATE INDEX ix_comments_entity ON comments (entity_type, entity_id);
CREATE INDEX ix_activity_entity ON activity_log (entity_type, entity_id, occurred_at DESC);
CREATE INDEX ix_notifications_unread ON notifications (user_id) WHERE read_at IS NULL;
CREATE INDEX ix_equipment_checks_due ON equipment_check_plans (organization_id, next_due_on) WHERE is_active;
CREATE INDEX ix_documents_review ON documents (organization_id, next_review_on) WHERE status = 'approved';
CREATE INDEX ix_register_entries_data ON register_entries USING gin (data);
CREATE INDEX ix_regulatory_texts_search ON regulatory_texts USING gin (to_tsvector('french', coalesce(reference,'') || ' ' || title || ' ' || coalesce(summary,'')));

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

-- ================================================================== row-level security
ALTER TABLE firms ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON firms FOR SELECT USING (app.can_read_firm(id));
CREATE POLICY p_write ON firms FOR UPDATE USING (app.is_firm_admin(id)) WITH CHECK (app.is_firm_admin(id));
CREATE TRIGGER trg_firms_touch BEFORE UPDATE ON firms FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON organizations FOR SELECT USING (app.can_access_org(id));
CREATE POLICY p_insert ON organizations FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON organizations FOR UPDATE USING (app.can_write_org(id)) WITH CHECK (app.can_write_org(id));
CREATE TRIGGER trg_organizations_firm_access BEFORE UPDATE OF firm_access ON organizations FOR EACH ROW EXECUTE FUNCTION app.guard_firm_access();
CREATE TRIGGER trg_organizations_touch BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON sites FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON sites FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON sites FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON sites FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_sites_touch BEFORE UPDATE ON sites FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON users FOR SELECT USING (id = app.current_user_id() OR app.is_platform_admin() OR EXISTS (SELECT 1 FROM org_memberships m WHERE m.user_id = users.id AND app.can_access_org(m.organization_id)) OR EXISTS (SELECT 1 FROM firm_members f WHERE f.user_id = users.id AND app.is_firm_member(f.firm_id)));
CREATE POLICY p_update ON users FOR UPDATE USING (id = app.current_user_id() OR app.is_platform_admin()) WITH CHECK (id = app.current_user_id() OR app.is_platform_admin());
ALTER TABLE firm_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON firm_members FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON firm_members FOR INSERT WITH CHECK (app.is_firm_admin(firm_id));
CREATE POLICY p_update ON firm_members FOR UPDATE USING (app.is_firm_admin(firm_id)) WITH CHECK (app.is_firm_admin(firm_id));
CREATE POLICY p_delete ON firm_members FOR DELETE USING (app.is_firm_admin(firm_id));
CREATE TRIGGER trg_firm_members_touch BEFORE UPDATE ON firm_members FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE org_memberships ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON org_memberships FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON org_memberships FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON org_memberships FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON org_memberships FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_org_memberships_touch BEFORE UPDATE ON org_memberships FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON roles FOR SELECT USING ((org_id IS NULL AND (firm_id IS NULL OR app.can_read_firm(firm_id))) OR (org_id IS NOT NULL AND app.can_access_org(org_id)));
CREATE POLICY p_insert ON roles FOR INSERT WITH CHECK ((org_id IS NOT NULL AND app.can_write_org(org_id)) OR (org_id IS NULL AND firm_id IS NOT NULL AND app.is_firm_admin(firm_id)) OR app.is_platform_admin());
CREATE POLICY p_update ON roles FOR UPDATE USING ((org_id IS NOT NULL AND app.can_write_org(org_id)) OR (org_id IS NULL AND firm_id IS NOT NULL AND app.is_firm_admin(firm_id)) OR app.is_platform_admin()) WITH CHECK ((org_id IS NOT NULL AND app.can_write_org(org_id)) OR (org_id IS NULL AND firm_id IS NOT NULL AND app.is_firm_admin(firm_id)) OR app.is_platform_admin());
CREATE POLICY p_delete ON roles FOR DELETE USING ((org_id IS NOT NULL AND app.can_write_org(org_id)) OR (org_id IS NULL AND firm_id IS NOT NULL AND app.is_firm_admin(firm_id)) OR app.is_platform_admin());
CREATE TRIGGER trg_roles_touch BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON permissions FOR SELECT USING (true);
CREATE POLICY p_insert ON permissions FOR INSERT WITH CHECK (app.is_platform_admin());
CREATE POLICY p_update ON permissions FOR UPDATE USING (app.is_platform_admin()) WITH CHECK (app.is_platform_admin());
CREATE POLICY p_delete ON permissions FOR DELETE USING (app.is_platform_admin());
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON role_permissions FOR SELECT USING (true);
CREATE POLICY p_insert ON role_permissions FOR INSERT WITH CHECK (app.is_platform_admin());
CREATE POLICY p_update ON role_permissions FOR UPDATE USING (app.is_platform_admin()) WITH CHECK (app.is_platform_admin());
CREATE POLICY p_delete ON role_permissions FOR DELETE USING (app.is_platform_admin());
CREATE TRIGGER trg_role_permissions_touch BEFORE UPDATE ON role_permissions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE membership_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON membership_roles FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON membership_roles FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON membership_roles FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON membership_roles FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_membership_roles_touch BEFORE UPDATE ON membership_roles FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON subscriptions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON subscriptions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON subscriptions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON subscriptions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_subscriptions_touch BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE consultant_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON consultant_assignments FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON consultant_assignments FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON consultant_assignments FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON consultant_assignments FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_consultant_assignments_touch BEFORE UPDATE ON consultant_assignments FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_all ON invitations FOR ALL USING (app.is_firm_member(firm_id) OR (target_org_id IS NOT NULL AND app.can_write_org(target_org_id))) WITH CHECK (app.is_firm_member(firm_id) OR (target_org_id IS NOT NULL AND app.can_write_org(target_org_id)));
CREATE TRIGGER trg_invitations_touch BEFORE UPDATE ON invitations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE files ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_all ON files FOR ALL USING ((org_id IS NOT NULL AND app.can_access_org(org_id)) OR (org_id IS NULL AND app.is_firm_member(firm_id))) WITH CHECK ((org_id IS NOT NULL AND app.can_access_org(org_id)) OR (org_id IS NULL AND app.is_firm_member(firm_id)));
CREATE TRIGGER trg_files_touch BEFORE UPDATE ON files FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON attachments FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON attachments FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON attachments FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON attachments FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_attachments_touch BEFORE UPDATE ON attachments FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON comments FOR SELECT USING (app.can_access_org(organization_id) AND (visibility = 'shared' OR app.is_firm_side(organization_id)));
CREATE POLICY p_insert ON comments FOR INSERT WITH CHECK (app.can_write_org(organization_id) AND (visibility = 'shared' OR app.is_firm_side(organization_id)));
CREATE POLICY p_update ON comments FOR UPDATE USING (app.can_write_org(organization_id) AND (visibility = 'shared' OR app.is_firm_side(organization_id))) WITH CHECK (app.can_write_org(organization_id) AND (visibility = 'shared' OR app.is_firm_side(organization_id)));
CREATE POLICY p_delete ON comments FOR DELETE USING (app.can_write_org(organization_id) AND (visibility = 'shared' OR app.is_firm_side(organization_id)));
CREATE TRIGGER trg_comments_touch BEFORE UPDATE ON comments FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_all ON notifications FOR ALL USING (user_id = app.current_user_id()) WITH CHECK (user_id = app.current_user_id());
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_all ON notification_preferences FOR ALL USING (user_id = app.current_user_id()) WITH CHECK (user_id = app.current_user_id());
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON activity_log FOR SELECT USING ((org_id IS NOT NULL AND app.can_access_org(org_id)) OR (org_id IS NULL AND app.is_firm_member(firm_id)));
CREATE POLICY p_insert ON activity_log FOR INSERT WITH CHECK ((org_id IS NOT NULL AND app.can_access_org(org_id)) OR (org_id IS NULL AND app.is_firm_member(firm_id)));
ALTER TABLE import_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON import_jobs FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON import_jobs FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON import_jobs FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON import_jobs FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_import_jobs_touch BEFORE UPDATE ON import_jobs FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE export_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON export_jobs FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON export_jobs FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON export_jobs FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON export_jobs FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_export_jobs_touch BEFORE UPDATE ON export_jobs FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE sectors ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON sectors FOR SELECT USING (firm_id IS NULL OR app.can_read_firm(firm_id));
CREATE POLICY p_insert ON sectors FOR INSERT WITH CHECK ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id));
CREATE POLICY p_update ON sectors FOR UPDATE USING ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id)) WITH CHECK ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id));
CREATE POLICY p_delete ON sectors FOR DELETE USING ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id));
CREATE TRIGGER trg_sectors_touch BEFORE UPDATE ON sectors FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE standards ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON standards FOR SELECT USING (true);
CREATE POLICY p_insert ON standards FOR INSERT WITH CHECK (app.is_platform_admin());
CREATE POLICY p_update ON standards FOR UPDATE USING (app.is_platform_admin()) WITH CHECK (app.is_platform_admin());
CREATE POLICY p_delete ON standards FOR DELETE USING (app.is_platform_admin());
CREATE TRIGGER trg_standards_touch BEFORE UPDATE ON standards FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE standard_editions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON standard_editions FOR SELECT USING (true);
CREATE POLICY p_insert ON standard_editions FOR INSERT WITH CHECK (app.is_platform_admin());
CREATE POLICY p_update ON standard_editions FOR UPDATE USING (app.is_platform_admin()) WITH CHECK (app.is_platform_admin());
CREATE POLICY p_delete ON standard_editions FOR DELETE USING (app.is_platform_admin());
CREATE TRIGGER trg_standard_editions_touch BEFORE UPDATE ON standard_editions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE clauses ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON clauses FOR SELECT USING (true);
CREATE POLICY p_insert ON clauses FOR INSERT WITH CHECK (app.is_platform_admin());
CREATE POLICY p_update ON clauses FOR UPDATE USING (app.is_platform_admin()) WITH CHECK (app.is_platform_admin());
CREATE POLICY p_delete ON clauses FOR DELETE USING (app.is_platform_admin());
CREATE TRIGGER trg_clauses_touch BEFORE UPDATE ON clauses FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE clause_correspondences ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON clause_correspondences FOR SELECT USING (true);
CREATE POLICY p_insert ON clause_correspondences FOR INSERT WITH CHECK (app.is_platform_admin());
CREATE POLICY p_update ON clause_correspondences FOR UPDATE USING (app.is_platform_admin()) WITH CHECK (app.is_platform_admin());
CREATE POLICY p_delete ON clause_correspondences FOR DELETE USING (app.is_platform_admin());
CREATE TRIGGER trg_clause_correspondences_touch BEFORE UPDATE ON clause_correspondences FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE regulatory_texts ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON regulatory_texts FOR SELECT USING (firm_id IS NULL OR app.can_read_firm(firm_id));
CREATE POLICY p_insert ON regulatory_texts FOR INSERT WITH CHECK ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id));
CREATE POLICY p_update ON regulatory_texts FOR UPDATE USING ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id)) WITH CHECK ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id));
CREATE POLICY p_delete ON regulatory_texts FOR DELETE USING ((firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(firm_id));
CREATE TRIGGER trg_regulatory_texts_touch BEFORE UPDATE ON regulatory_texts FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE regulatory_requirements ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON regulatory_requirements FOR SELECT USING (EXISTS (SELECT 1 FROM regulatory_texts p WHERE p.id = text_id));
CREATE POLICY p_insert ON regulatory_requirements FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM regulatory_texts p WHERE p.id = text_id AND ((p.firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(p.firm_id))));
CREATE POLICY p_update ON regulatory_requirements FOR UPDATE USING (EXISTS (SELECT 1 FROM regulatory_texts p WHERE p.id = text_id AND ((p.firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(p.firm_id)))) WITH CHECK (EXISTS (SELECT 1 FROM regulatory_texts p WHERE p.id = text_id AND ((p.firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(p.firm_id))));
CREATE POLICY p_delete ON regulatory_requirements FOR DELETE USING (EXISTS (SELECT 1 FROM regulatory_texts p WHERE p.id = text_id AND ((p.firm_id IS NULL AND app.is_platform_admin()) OR app.is_firm_member(p.firm_id))));
CREATE TRIGGER trg_regulatory_requirements_touch BEFORE UPDATE ON regulatory_requirements FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE substance_compatibility_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON substance_compatibility_rules FOR SELECT USING (true);
CREATE POLICY p_insert ON substance_compatibility_rules FOR INSERT WITH CHECK (app.is_platform_admin());
CREATE POLICY p_update ON substance_compatibility_rules FOR UPDATE USING (app.is_platform_admin()) WITH CHECK (app.is_platform_admin());
CREATE POLICY p_delete ON substance_compatibility_rules FOR DELETE USING (app.is_platform_admin());
CREATE TRIGGER trg_substance_compatibility_rules_touch BEFORE UPDATE ON substance_compatibility_rules FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE scoring_models ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON scoring_models FOR SELECT USING ((org_id IS NULL AND app.can_read_firm(firm_id)) OR (org_id IS NOT NULL AND app.can_access_org(org_id)));
CREATE POLICY p_insert ON scoring_models FOR INSERT WITH CHECK ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id)));
CREATE POLICY p_update ON scoring_models FOR UPDATE USING ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id))) WITH CHECK ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id)));
CREATE POLICY p_delete ON scoring_models FOR DELETE USING ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id)));
CREATE TRIGGER trg_scoring_models_touch BEFORE UPDATE ON scoring_models FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE scoring_dimensions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON scoring_dimensions FOR SELECT USING (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id));
CREATE POLICY p_insert ON scoring_dimensions FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE POLICY p_update ON scoring_dimensions FOR UPDATE USING (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id))))) WITH CHECK (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE POLICY p_delete ON scoring_dimensions FOR DELETE USING (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE TRIGGER trg_scoring_dimensions_touch BEFORE UPDATE ON scoring_dimensions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE scoring_levels ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON scoring_levels FOR SELECT USING (EXISTS (SELECT 1 FROM scoring_dimensions d JOIN scoring_models m ON m.id = d.model_id WHERE d.id = dimension_id AND ((m.org_id IS NULL AND app.can_read_firm(m.firm_id)) OR (m.org_id IS NOT NULL AND app.can_access_org(m.org_id)))));
CREATE POLICY p_insert ON scoring_levels FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM scoring_dimensions d JOIN scoring_models p ON p.id = d.model_id WHERE d.id = dimension_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE POLICY p_update ON scoring_levels FOR UPDATE USING (EXISTS (SELECT 1 FROM scoring_dimensions d JOIN scoring_models p ON p.id = d.model_id WHERE d.id = dimension_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id))))) WITH CHECK (EXISTS (SELECT 1 FROM scoring_dimensions d JOIN scoring_models p ON p.id = d.model_id WHERE d.id = dimension_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE POLICY p_delete ON scoring_levels FOR DELETE USING (EXISTS (SELECT 1 FROM scoring_dimensions d JOIN scoring_models p ON p.id = d.model_id WHERE d.id = dimension_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE TRIGGER trg_scoring_levels_touch BEFORE UPDATE ON scoring_levels FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE scoring_bands ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON scoring_bands FOR SELECT USING (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id));
CREATE POLICY p_insert ON scoring_bands FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE POLICY p_update ON scoring_bands FOR UPDATE USING (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id))))) WITH CHECK (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE POLICY p_delete ON scoring_bands FOR DELETE USING (EXISTS (SELECT 1 FROM scoring_models p WHERE p.id = model_id AND ((p.org_id IS NULL AND app.is_firm_member(p.firm_id)) OR (p.org_id IS NOT NULL AND app.can_write_org(p.org_id)))));
CREATE TRIGGER trg_scoring_bands_touch BEFORE UPDATE ON scoring_bands FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE kits ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON kits FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON kits FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON kits FOR UPDATE USING (app.is_firm_member(firm_id)) WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_delete ON kits FOR DELETE USING (app.is_firm_member(firm_id));
CREATE TRIGGER trg_kits_touch BEFORE UPDATE ON kits FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE kit_editions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON kit_editions FOR SELECT USING (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id));
CREATE POLICY p_insert ON kit_editions FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id)));
CREATE POLICY p_update ON kit_editions FOR UPDATE USING (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id))) WITH CHECK (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id)));
CREATE POLICY p_delete ON kit_editions FOR DELETE USING (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id)));
CREATE TRIGGER trg_kit_editions_touch BEFORE UPDATE ON kit_editions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE kit_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON kit_items FOR SELECT USING (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id));
CREATE POLICY p_insert ON kit_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id)));
CREATE POLICY p_update ON kit_items FOR UPDATE USING (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id))) WITH CHECK (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id)));
CREATE POLICY p_delete ON kit_items FOR DELETE USING (EXISTS (SELECT 1 FROM kits p WHERE p.id = kit_id AND app.is_firm_member(p.firm_id)));
CREATE TRIGGER trg_kit_items_touch BEFORE UPDATE ON kit_items FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_templates FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON document_templates FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON document_templates FOR UPDATE USING (app.is_firm_member(firm_id)) WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_delete ON document_templates FOR DELETE USING (app.is_firm_member(firm_id));
CREATE TRIGGER trg_document_templates_touch BEFORE UPDATE ON document_templates FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE template_clauses ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON template_clauses FOR SELECT USING (EXISTS (SELECT 1 FROM document_templates p WHERE p.id = document_template_id));
CREATE POLICY p_insert ON template_clauses FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM document_templates p WHERE p.id = document_template_id AND app.is_firm_member(p.firm_id)));
CREATE POLICY p_update ON template_clauses FOR UPDATE USING (EXISTS (SELECT 1 FROM document_templates p WHERE p.id = document_template_id AND app.is_firm_member(p.firm_id))) WITH CHECK (EXISTS (SELECT 1 FROM document_templates p WHERE p.id = document_template_id AND app.is_firm_member(p.firm_id)));
CREATE POLICY p_delete ON template_clauses FOR DELETE USING (EXISTS (SELECT 1 FROM document_templates p WHERE p.id = document_template_id AND app.is_firm_member(p.firm_id)));
CREATE TRIGGER trg_template_clauses_touch BEFORE UPDATE ON template_clauses FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE process_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON process_templates FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON process_templates FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON process_templates FOR UPDATE USING (app.is_firm_member(firm_id)) WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_delete ON process_templates FOR DELETE USING (app.is_firm_member(firm_id));
CREATE TRIGGER trg_process_templates_touch BEFORE UPDATE ON process_templates FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE indicator_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON indicator_templates FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON indicator_templates FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON indicator_templates FOR UPDATE USING (app.is_firm_member(firm_id)) WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_delete ON indicator_templates FOR DELETE USING (app.is_firm_member(firm_id));
CREATE TRIGGER trg_indicator_templates_touch BEFORE UPDATE ON indicator_templates FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE risk_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON risk_templates FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON risk_templates FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON risk_templates FOR UPDATE USING (app.is_firm_member(firm_id)) WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_delete ON risk_templates FOR DELETE USING (app.is_firm_member(firm_id));
CREATE TRIGGER trg_risk_templates_touch BEFORE UPDATE ON risk_templates FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE clause_evidence_expectations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON clause_evidence_expectations FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON clause_evidence_expectations FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON clause_evidence_expectations FOR UPDATE USING (app.is_firm_member(firm_id)) WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_delete ON clause_evidence_expectations FOR DELETE USING (app.is_firm_member(firm_id));
CREATE TRIGGER trg_clause_evidence_expectations_touch BEFORE UPDATE ON clause_evidence_expectations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE certification_bodies ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON certification_bodies FOR SELECT USING (app.can_read_firm(firm_id));
CREATE POLICY p_insert ON certification_bodies FOR INSERT WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_update ON certification_bodies FOR UPDATE USING (app.is_firm_member(firm_id)) WITH CHECK (app.is_firm_member(firm_id));
CREATE POLICY p_delete ON certification_bodies FOR DELETE USING (app.is_firm_member(firm_id));
CREATE TRIGGER trg_certification_bodies_touch BEFORE UPDATE ON certification_bodies FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE engagements ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON engagements FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON engagements FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON engagements FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON engagements FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_engagements_touch BEFORE UPDATE ON engagements FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE engagement_editions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON engagement_editions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON engagement_editions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON engagement_editions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON engagement_editions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_engagement_editions_touch BEFORE UPDATE ON engagement_editions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE engagement_milestones ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON engagement_milestones FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON engagement_milestones FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON engagement_milestones FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON engagement_milestones FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_engagement_milestones_touch BEFORE UPDATE ON engagement_milestones FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE deliverables ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON deliverables FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON deliverables FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON deliverables FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON deliverables FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_deliverables_touch BEFORE UPDATE ON deliverables FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE consultant_visits ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON consultant_visits FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON consultant_visits FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON consultant_visits FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON consultant_visits FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_consultant_visits_touch BEFORE UPDATE ON consultant_visits FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE gap_assessments ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON gap_assessments FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON gap_assessments FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON gap_assessments FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON gap_assessments FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_gap_assessments_touch BEFORE UPDATE ON gap_assessments FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE gap_assessment_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON gap_assessment_items FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON gap_assessment_items FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON gap_assessment_items FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON gap_assessment_items FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_gap_assessment_items_touch BEFORE UPDATE ON gap_assessment_items FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE readiness_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON readiness_snapshots FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON readiness_snapshots FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON readiness_snapshots FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON readiness_snapshots FOR DELETE USING (app.can_write_org(organization_id));
ALTER TABLE certificates ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON certificates FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON certificates FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON certificates FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON certificates FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_certificates_touch BEFORE UPDATE ON certificates FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE management_systems ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON management_systems FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON management_systems FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON management_systems FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON management_systems FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_management_systems_touch BEFORE UPDATE ON management_systems FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE management_system_editions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON management_system_editions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON management_system_editions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON management_system_editions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON management_system_editions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_management_system_editions_touch BEFORE UPDATE ON management_system_editions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE clause_exclusions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON clause_exclusions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON clause_exclusions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON clause_exclusions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON clause_exclusions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_clause_exclusions_touch BEFORE UPDATE ON clause_exclusions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE context_issues ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON context_issues FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON context_issues FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON context_issues FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON context_issues FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_context_issues_touch BEFORE UPDATE ON context_issues FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE interested_parties ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON interested_parties FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON interested_parties FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON interested_parties FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON interested_parties FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_interested_parties_touch BEFORE UPDATE ON interested_parties FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE party_requirements ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON party_requirements FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON party_requirements FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON party_requirements FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON party_requirements FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_party_requirements_touch BEFORE UPDATE ON party_requirements FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE policy_axes ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON policy_axes FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON policy_axes FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON policy_axes FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON policy_axes FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_policy_axes_touch BEFORE UPDATE ON policy_axes FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE processes ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON processes FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON processes FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON processes FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON processes FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_processes_touch BEFORE UPDATE ON processes FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE process_steps ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON process_steps FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON process_steps FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON process_steps FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON process_steps FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_process_steps_touch BEFORE UPDATE ON process_steps FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE process_step_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON process_step_documents FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON process_step_documents FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON process_step_documents FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON process_step_documents FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_process_step_documents_touch BEFORE UPDATE ON process_step_documents FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE process_interactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON process_interactions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON process_interactions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON process_interactions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON process_interactions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_process_interactions_touch BEFORE UPDATE ON process_interactions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE process_clauses ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON process_clauses FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON process_clauses FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON process_clauses FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON process_clauses FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_process_clauses_touch BEFORE UPDATE ON process_clauses FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE process_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON process_reviews FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON process_reviews FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON process_reviews FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON process_reviews FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_process_reviews_touch BEFORE UPDATE ON process_reviews FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_types FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON document_types FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON document_types FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON document_types FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_document_types_touch BEFORE UPDATE ON document_types FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON documents FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON documents FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON documents FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON documents FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_documents_touch BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_versions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON document_versions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON document_versions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON document_versions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_document_versions_lock BEFORE UPDATE OR DELETE ON document_versions FOR EACH ROW EXECUTE FUNCTION app.protect_approved_version();
CREATE TRIGGER trg_document_versions_touch BEFORE UPDATE ON document_versions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_approvals ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_approvals FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON document_approvals FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON document_approvals FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON document_approvals FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_document_approvals_touch BEFORE UPDATE ON document_approvals FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE distribution_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON distribution_points FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON distribution_points FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON distribution_points FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON distribution_points FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_distribution_points_touch BEFORE UPDATE ON distribution_points FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_distributions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_distributions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON document_distributions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON document_distributions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON document_distributions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_document_distributions_touch BEFORE UPDATE ON document_distributions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_acknowledgements ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_acknowledgements FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON document_acknowledgements FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON document_acknowledgements FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON document_acknowledgements FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_document_acknowledgements_touch BEFORE UPDATE ON document_acknowledgements FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_clauses ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_clauses FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON document_clauses FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON document_clauses FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON document_clauses FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_document_clauses_touch BEFORE UPDATE ON document_clauses FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE document_sequences ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON document_sequences FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON document_sequences FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON document_sequences FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON document_sequences FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_document_sequences_touch BEFORE UPDATE ON document_sequences FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE register_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON register_definitions FOR SELECT USING ((org_id IS NULL AND app.can_read_firm(firm_id)) OR (org_id IS NOT NULL AND app.can_access_org(org_id)));
CREATE POLICY p_insert ON register_definitions FOR INSERT WITH CHECK ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id)));
CREATE POLICY p_update ON register_definitions FOR UPDATE USING ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id))) WITH CHECK ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id)));
CREATE POLICY p_delete ON register_definitions FOR DELETE USING ((org_id IS NULL AND app.is_firm_member(firm_id)) OR (org_id IS NOT NULL AND app.can_write_org(org_id)));
CREATE TRIGGER trg_register_definitions_touch BEFORE UPDATE ON register_definitions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE register_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON register_entries FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON register_entries FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON register_entries FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON register_entries FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_register_entries_touch BEFORE UPDATE ON register_entries FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE change_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON change_requests FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON change_requests FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON change_requests FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON change_requests FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_change_requests_touch BEFORE UPDATE ON change_requests FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE change_impacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON change_impacts FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON change_impacts FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON change_impacts FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON change_impacts FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_change_impacts_touch BEFORE UPDATE ON change_impacts FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE knowledge_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON knowledge_items FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON knowledge_items FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON knowledge_items FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON knowledge_items FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_knowledge_items_touch BEFORE UPDATE ON knowledge_items FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON activities FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON activities FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON activities FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON activities FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_activities_touch BEFORE UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE risk_assessments ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON risk_assessments FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON risk_assessments FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON risk_assessments FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON risk_assessments FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_risk_assessments_touch BEFORE UPDATE ON risk_assessments FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE risk_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON risk_items FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON risk_items FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON risk_items FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON risk_items FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_risk_items_touch BEFORE UPDATE ON risk_items FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE ohs_hazard_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON ohs_hazard_details FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON ohs_hazard_details FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON ohs_hazard_details FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON ohs_hazard_details FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_ohs_hazard_details_touch BEFORE UPDATE ON ohs_hazard_details FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE env_aspect_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON env_aspect_details FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON env_aspect_details FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON env_aspect_details FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON env_aspect_details FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_env_aspect_details_touch BEFORE UPDATE ON env_aspect_details FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE risk_evaluations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON risk_evaluations FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON risk_evaluations FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON risk_evaluations FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON risk_evaluations FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_risk_evaluations_touch BEFORE UPDATE ON risk_evaluations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE risk_evaluation_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON risk_evaluation_scores FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON risk_evaluation_scores FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON risk_evaluation_scores FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON risk_evaluation_scores FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_risk_evaluation_scores_touch BEFORE UPDATE ON risk_evaluation_scores FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE emergency_situations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON emergency_situations FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON emergency_situations FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON emergency_situations FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON emergency_situations FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_emergency_situations_touch BEFORE UPDATE ON emergency_situations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE emergency_drills ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON emergency_drills FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON emergency_drills FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON emergency_drills FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON emergency_drills FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_emergency_drills_touch BEFORE UPDATE ON emergency_drills FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE hazardous_substances ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON hazardous_substances FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON hazardous_substances FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON hazardous_substances FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON hazardous_substances FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_hazardous_substances_touch BEFORE UPDATE ON hazardous_substances FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE compliance_obligations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON compliance_obligations FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON compliance_obligations FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON compliance_obligations FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON compliance_obligations FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_compliance_obligations_touch BEFORE UPDATE ON compliance_obligations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE compliance_evaluations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON compliance_evaluations FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON compliance_evaluations FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON compliance_evaluations FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON compliance_evaluations FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_compliance_evaluations_touch BEFORE UPDATE ON compliance_evaluations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE objectives ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON objectives FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON objectives FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON objectives FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON objectives FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_objectives_touch BEFORE UPDATE ON objectives FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE indicators ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON indicators FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON indicators FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON indicators FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON indicators FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_indicators_touch BEFORE UPDATE ON indicators FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE indicator_measurements ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON indicator_measurements FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON indicator_measurements FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON indicator_measurements FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON indicator_measurements FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_indicator_measurements_touch BEFORE UPDATE ON indicator_measurements FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON customers FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON customers FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON customers FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON customers FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_customers_touch BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON projects FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON projects FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON projects FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON projects FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_projects_touch BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE customer_surveys ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON customer_surveys FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON customer_surveys FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON customer_surveys FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON customer_surveys FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_customer_surveys_touch BEFORE UPDATE ON customer_surveys FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON complaints FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON complaints FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON complaints FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON complaints FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_complaints_touch BEFORE UPDATE ON complaints FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON incidents FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON incidents FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON incidents FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON incidents FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_incidents_touch BEFORE UPDATE ON incidents FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE nonconformities ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON nonconformities FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON nonconformities FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON nonconformities FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON nonconformities FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_nonconformities_touch BEFORE UPDATE ON nonconformities FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE nonconformity_clauses ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON nonconformity_clauses FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON nonconformity_clauses FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON nonconformity_clauses FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON nonconformity_clauses FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_nonconformity_clauses_touch BEFORE UPDATE ON nonconformity_clauses FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON actions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON actions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON actions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON actions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_actions_touch BEFORE UPDATE ON actions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE action_owners ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON action_owners FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON action_owners FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON action_owners FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON action_owners FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_action_owners_touch BEFORE UPDATE ON action_owners FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE action_updates ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON action_updates FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON action_updates FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON action_updates FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON action_updates FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_action_updates_touch BEFORE UPDATE ON action_updates FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audit_programs ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audit_programs FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audit_programs FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audit_programs FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audit_programs FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audit_programs_touch BEFORE UPDATE ON audit_programs FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audit_program_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audit_program_items FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audit_program_items FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audit_program_items FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audit_program_items FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audit_program_items_touch BEFORE UPDATE ON audit_program_items FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audits ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audits FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audits FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audits FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audits FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audits_touch BEFORE UPDATE ON audits FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audit_editions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audit_editions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audit_editions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audit_editions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audit_editions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audit_editions_touch BEFORE UPDATE ON audit_editions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audit_team_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audit_team_members FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audit_team_members FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audit_team_members FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audit_team_members FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audit_team_members_touch BEFORE UPDATE ON audit_team_members FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audit_plan_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audit_plan_slots FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audit_plan_slots FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audit_plan_slots FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audit_plan_slots FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audit_plan_slots_touch BEFORE UPDATE ON audit_plan_slots FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audit_checklist_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audit_checklist_items FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audit_checklist_items FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audit_checklist_items FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audit_checklist_items FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audit_checklist_items_touch BEFORE UPDATE ON audit_checklist_items FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE audit_findings ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON audit_findings FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON audit_findings FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON audit_findings FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON audit_findings FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_audit_findings_touch BEFORE UPDATE ON audit_findings FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE management_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON management_reviews FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON management_reviews FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON management_reviews FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON management_reviews FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_management_reviews_touch BEFORE UPDATE ON management_reviews FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE management_review_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON management_review_participants FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON management_review_participants FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON management_review_participants FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON management_review_participants FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_management_review_participants_touch BEFORE UPDATE ON management_review_participants FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE management_review_inputs ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON management_review_inputs FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON management_review_inputs FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON management_review_inputs FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON management_review_inputs FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_management_review_inputs_touch BEFORE UPDATE ON management_review_inputs FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE management_review_decisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON management_review_decisions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON management_review_decisions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON management_review_decisions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON management_review_decisions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_management_review_decisions_touch BEFORE UPDATE ON management_review_decisions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE positions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON positions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON positions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON positions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON positions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_positions_touch BEFORE UPDATE ON positions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON employees FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON employees FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON employees FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON employees FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_employees_touch BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE competencies ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON competencies FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON competencies FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON competencies FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON competencies FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_competencies_touch BEFORE UPDATE ON competencies FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE position_competencies ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON position_competencies FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON position_competencies FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON position_competencies FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON position_competencies FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_position_competencies_touch BEFORE UPDATE ON position_competencies FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE competency_evaluations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON competency_evaluations FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON competency_evaluations FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON competency_evaluations FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON competency_evaluations FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_competency_evaluations_touch BEFORE UPDATE ON competency_evaluations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE employee_qualifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON employee_qualifications FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON employee_qualifications FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON employee_qualifications FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON employee_qualifications FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_employee_qualifications_touch BEFORE UPDATE ON employee_qualifications FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE training_needs ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON training_needs FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON training_needs FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON training_needs FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON training_needs FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_training_needs_touch BEFORE UPDATE ON training_needs FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON training_plans FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON training_plans FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON training_plans FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON training_plans FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_training_plans_touch BEFORE UPDATE ON training_plans FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE training_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON training_sessions FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON training_sessions FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON training_sessions FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON training_sessions FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_training_sessions_touch BEFORE UPDATE ON training_sessions FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE training_attendances ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON training_attendances FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON training_attendances FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON training_attendances FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON training_attendances FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_training_attendances_touch BEFORE UPDATE ON training_attendances FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE recruitment_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON recruitment_requests FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON recruitment_requests FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON recruitment_requests FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON recruitment_requests FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_recruitment_requests_touch BEFORE UPDATE ON recruitment_requests FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE onboarding_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON onboarding_plans FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON onboarding_plans FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON onboarding_plans FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON onboarding_plans FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_onboarding_plans_touch BEFORE UPDATE ON onboarding_plans FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE medical_visits ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_all ON medical_visits FOR ALL USING (app.has_permission(organization_id, 'hr.medical.read')) WITH CHECK (app.has_permission(organization_id, 'hr.medical.read'));
CREATE TRIGGER trg_medical_visits_touch BEFORE UPDATE ON medical_visits FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE ppe_issues ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON ppe_issues FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON ppe_issues FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON ppe_issues FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON ppe_issues FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_ppe_issues_touch BEFORE UPDATE ON ppe_issues FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE communication_plan_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON communication_plan_items FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON communication_plan_items FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON communication_plan_items FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON communication_plan_items FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_communication_plan_items_touch BEFORE UPDATE ON communication_plan_items FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE communication_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON communication_records FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON communication_records FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON communication_records FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON communication_records FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_communication_records_touch BEFORE UPDATE ON communication_records FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE worker_meetings ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON worker_meetings FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON worker_meetings FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON worker_meetings FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON worker_meetings FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_worker_meetings_touch BEFORE UPDATE ON worker_meetings FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE worker_meeting_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON worker_meeting_participants FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON worker_meeting_participants FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON worker_meeting_participants FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON worker_meeting_participants FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_worker_meeting_participants_touch BEFORE UPDATE ON worker_meeting_participants FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE visitor_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON visitor_logs FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON visitor_logs FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON visitor_logs FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON visitor_logs FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_visitor_logs_touch BEFORE UPDATE ON visitor_logs FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON suppliers FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON suppliers FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON suppliers FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON suppliers FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_suppliers_touch BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE supplier_criteria ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON supplier_criteria FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON supplier_criteria FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON supplier_criteria FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON supplier_criteria FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_supplier_criteria_touch BEFORE UPDATE ON supplier_criteria FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE supplier_evaluations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON supplier_evaluations FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON supplier_evaluations FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON supplier_evaluations FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON supplier_evaluations FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_supplier_evaluations_touch BEFORE UPDATE ON supplier_evaluations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE supplier_evaluation_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON supplier_evaluation_scores FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON supplier_evaluation_scores FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON supplier_evaluation_scores FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON supplier_evaluation_scores FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_supplier_evaluation_scores_touch BEFORE UPDATE ON supplier_evaluation_scores FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON equipment FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON equipment FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON equipment FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON equipment FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_equipment_touch BEFORE UPDATE ON equipment FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE equipment_check_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON equipment_check_plans FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON equipment_check_plans FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON equipment_check_plans FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON equipment_check_plans FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_equipment_check_plans_touch BEFORE UPDATE ON equipment_check_plans FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE equipment_checks ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON equipment_checks FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON equipment_checks FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON equipment_checks FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON equipment_checks FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_equipment_checks_touch BEFORE UPDATE ON equipment_checks FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE equipment_check_reservations ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON equipment_check_reservations FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON equipment_check_reservations FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON equipment_check_reservations FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON equipment_check_reservations FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_equipment_check_reservations_touch BEFORE UPDATE ON equipment_check_reservations FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE control_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON control_plans FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON control_plans FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON control_plans FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON control_plans FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_control_plans_touch BEFORE UPDATE ON control_plans FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE control_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON control_points FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON control_points FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON control_points FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON control_points FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_control_points_touch BEFORE UPDATE ON control_points FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON inspections FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON inspections FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON inspections FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON inspections FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_inspections_touch BEFORE UPDATE ON inspections FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE inspection_results ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON inspection_results FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON inspection_results FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON inspection_results FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON inspection_results FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_inspection_results_touch BEFORE UPDATE ON inspection_results FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE waste_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON waste_records FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON waste_records FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON waste_records FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON waste_records FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_waste_records_touch BEFORE UPDATE ON waste_records FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON consumption_records FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON consumption_records FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON consumption_records FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON consumption_records FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_consumption_records_touch BEFORE UPDATE ON consumption_records FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
ALTER TABLE environmental_measurements ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_read ON environmental_measurements FOR SELECT USING (app.can_access_org(organization_id));
CREATE POLICY p_insert ON environmental_measurements FOR INSERT WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_update ON environmental_measurements FOR UPDATE USING (app.can_write_org(organization_id)) WITH CHECK (app.can_write_org(organization_id));
CREATE POLICY p_delete ON environmental_measurements FOR DELETE USING (app.can_write_org(organization_id));
CREATE TRIGGER trg_environmental_measurements_touch BEFORE UPDATE ON environmental_measurements FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

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

-- ================================================================== seed: system roles & permissions
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


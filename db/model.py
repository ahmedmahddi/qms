"""QMS platform data model — single source of truth.

Column spec string:  "name:type:flags:comment"
  type   : SQL type or enum name (blank => uuid, for FKs)
  flags  : space-separated
           nn            NOT NULL
           fk=<table>    foreign key to <table>.id
           del=cascade|setnull|restrict   (default: restrict if nn, setnull otherwise)
           def=<sql>     default expression
           uq            unique
"""

ENUMS = {
    # platform
    "org_type": ["client", "internal", "prospect"],
    "firm_access": ["full", "read_only", "none"],
    "subscription_plan": ["with_engagement", "standalone", "trial"],
    "subscription_status": ["trial", "active", "past_due", "suspended", "cancelled"],
    "firm_role": ["owner", "admin", "consultant"],
    "role_scope": ["firm", "organization"],
    "record_status": ["active", "archived"],
    "site_type": ["head_office", "warehouse", "workshop", "worksite", "zone", "fleet", "other"],
    "comment_visibility": ["shared", "firm_internal"],
    "job_status": ["pending", "mapping", "validating", "running", "done", "failed"],
    "export_format": ["docx", "xlsx", "pdf"],
    # standards & library
    "qse_system": ["quality", "ohs", "environment", "integrated"],
    "edition_status": ["draft", "active", "withdrawn"],
    "doc_info_requirement": ["none", "maintain", "retain", "maintain_and_retain"],
    "correspondence_type": ["equivalent", "modified", "new", "removed", "split", "merged"],
    "regulatory_text_type": ["law", "decree", "order", "circular", "code", "standard", "convention", "other"],
    "regulatory_status": ["in_force", "amended", "repealed"],
    "scoring_kind": ["risk_opportunity", "ohs", "environmental", "objective", "action_efficacy", "supplier"],
    "dimension_role": ["factor", "mastery", "efficacy"],
    "kit_item_type": ["document_template", "process_template", "register_definition", "indicator_template",
                      "risk_template", "scoring_model", "competency", "control_plan"],
    # engagement
    "engagement_status": ["prospect", "diagnostic", "design", "deployment", "internal_audit", "mock_audit",
                          "certification", "surveillance", "closed", "lost"],
    "assignment_role": ["lead", "support", "auditor", "reviewer"],
    "milestone_status": ["planned", "in_progress", "done", "late", "cancelled"],
    "deliverable_status": ["todo", "in_progress", "in_review", "delivered", "accepted"],
    "visit_mode": ["onsite", "remote"],
    "gap_type": ["initial", "intermediate", "pre_certification", "transition"],
    "gap_status": ["conforming", "partial", "nonconforming", "not_applicable", "not_assessed"],
    "certificate_status": ["valid", "suspended", "withdrawn", "expired"],
    # context
    "issue_nature": ["internal", "external"],
    "swot_type": ["strength", "weakness", "opportunity", "threat"],
    # processes
    "process_type": ["management", "operational", "support"],
    "review_conclusion": ["effective", "partially_effective", "not_effective"],
    # documents
    "doc_category": ["policy", "process_sheet", "procedure", "instruction", "manual", "plan", "list", "form",
                     "record", "external"],
    "doc_status": ["draft", "in_review", "approved", "obsolete", "archived"],
    "version_status": ["draft", "in_verification", "in_approval", "approved", "rejected", "superseded"],
    "approval_step": ["writing", "verification", "approval"],
    "approval_decision": ["pending", "approved", "rejected", "changes_requested"],
    "confidentiality": ["public", "internal", "restricted", "confidential"],
    "doc_source": ["created", "imported", "external", "from_template"],
    "distribution_purpose": ["application", "information"],
    "change_type": ["process", "organization", "equipment", "product_service", "legal", "document", "site",
                    "supplier", "other"],
    "change_status": ["requested", "assessed", "approved", "implemented", "verified", "rejected"],
    # risks
    "risk_kind": ["risk", "opportunity", "ohs_hazard", "env_aspect"],
    "assessment_kind": ["risk_opportunity", "ohs", "environmental"],
    "plan_status": ["draft", "approved", "in_progress", "closed"],
    "activity_type": ["office", "worksite", "workshop", "storage", "travel", "other"],
    "cause_category": ["man", "machine", "method", "material", "environment", "measurement"],
    "eval_phase": ["initial", "residual", "reassessment"],
    "routine_type": ["routine", "non_routine"],
    "env_condition": ["normal", "abnormal", "emergency"],
    "lifecycle_stage": ["raw_material", "design", "production", "transport", "installation", "use",
                        "end_of_life"],
    "control_level": ["control", "influence"],
    "session_status": ["planned", "done", "postponed", "cancelled"],
    # compliance
    "obligation_source": ["legal", "customer", "interested_party", "voluntary", "standard"],
    "compliance_status": ["compliant", "partially_compliant", "non_compliant", "not_applicable",
                          "not_evaluated"],
    "frequency": ["daily", "weekly", "monthly", "quarterly", "semiannual", "annual", "biennial", "ad_hoc"],
    # objectives
    "objective_status": ["planned", "in_progress", "achieved", "partially_achieved", "not_achieved",
                         "cancelled"],
    "comparator": ["gte", "lte", "eq", "gt", "lt", "between"],
    # NC / actions
    "nc_source": ["internal_audit", "external_audit", "gap_assessment", "indicator", "customer_complaint",
                  "product_service", "supplier", "incident", "emergency_drill", "legal_compliance",
                  "inspection", "management_review", "worker_consultation", "register_entry", "other"],
    "nc_severity": ["major", "minor", "observation"],
    "nc_status": ["open", "analysis", "action_planned", "in_progress", "verification", "closed", "cancelled"],
    "rca_method": ["five_whys", "ishikawa", "five_m", "fault_tree", "other"],
    "action_type": ["correction", "corrective", "preventive", "improvement", "risk_treatment", "opportunity",
                    "objective", "compliance", "other"],
    "action_source": ["nonconformity", "risk", "objective", "audit_finding", "management_review", "gap_assessment",
                      "compliance", "change", "worker_meeting", "emergency_drill", "equipment_check",
                      "inspection", "standalone"],
    "action_status": ["planned", "in_progress", "done", "effective", "ineffective", "cancelled"],
    "priority": ["low", "medium", "high", "critical"],
    "incident_type": ["lost_time_accident", "no_lost_time_accident", "first_aid", "near_miss",
                      "occupational_disease", "commute_accident", "env_incident", "property_damage"],
    "incident_status": ["reported", "investigating", "actions_planned", "closed"],
    "complaint_status": ["received", "analysing", "answered", "closed", "rejected"],
    # audits
    "audit_type": ["internal", "supplier", "mock", "certification_stage1", "certification_stage2",
                   "surveillance", "recertification", "transition", "second_party"],
    "audit_status": ["planned", "scheduled", "in_progress", "reporting", "closed", "cancelled"],
    "audit_role": ["lead_auditor", "auditor", "observer", "technical_expert", "auditee_guide"],
    "checklist_result": ["conforming", "nonconforming", "observation", "not_audited"],
    "finding_type": ["major_nc", "minor_nc", "observation", "improvement_opportunity", "strength"],
    "finding_status": ["open", "answered", "accepted", "closed"],
    # management review
    "review_status": ["planned", "preparing", "held", "minutes_approved"],
    "mr_input": ["previous_actions", "context_changes", "interested_party_needs", "customer_satisfaction",
                 "objectives", "process_performance", "nonconformities", "monitoring_results", "audit_results",
                 "supplier_performance", "resources", "risk_actions", "improvement_opportunities",
                 "compliance_obligations", "ohs_incidents", "worker_consultation", "env_performance",
                 "communications"],
    "mr_output": ["improvement", "system_change", "resources", "objectives", "policy", "other"],
    # people
    "employee_status": ["active", "on_leave", "left"],
    "contract_type": ["cdi", "cdd", "sivp", "intern", "interim", "subcontractor"],
    "competency_category": ["technical", "qse", "managerial", "regulatory_authorization", "language", "other"],
    "need_source": ["evaluation", "new_hire", "regulation", "incident", "nonconformity", "objective", "request"],
    "session_kind": ["training", "awareness", "induction", "toolbox_talk", "drill_briefing"],
    "request_status": ["draft", "submitted", "approved", "rejected", "done"],
    "medical_visit_type": ["hiring", "periodic", "return_to_work", "on_request"],
    "fitness": ["fit", "fit_with_restrictions", "unfit", "pending"],
    "direction": ["internal", "external"],
    "meeting_role": ["worker_representative", "manager", "qse", "guest"],
    # operations
    "supplier_category": ["product", "service", "subcontractor", "transport", "training", "laboratory",
                          "certification", "other"],
    "supplier_decision": ["pending", "approved", "conditional", "rejected"],
    "evaluation_kind": ["selection", "periodic", "post_incident"],
    "equipment_category": ["measuring_instrument", "lifting", "fire_protection", "electrical_installation",
                           "vehicle", "tool", "pressure_equipment", "collective_protection", "other"],
    "equipment_status": ["in_service", "out_of_service", "under_repair", "scrapped"],
    "check_type": ["calibration", "verification", "regulatory_inspection", "preventive_maintenance",
                   "corrective_maintenance"],
    "check_result": ["pending", "conforming", "conforming_with_reservations", "nonconforming"],
    "reservation_status": ["open", "lifted"],
    "control_plan_kind": ["receiving", "in_process", "final", "hse_inspection", "site_quality", "other"],
    "inspection_status": ["planned", "in_progress", "done", "cancelled"],
    "point_result": ["ok", "nok", "na"],
    "project_status": ["tender", "planned", "in_progress", "reception", "closed", "cancelled"],
    "resource_type": ["electricity", "water", "fuel", "gas", "paper", "other"],
    "compat_rule": ["compatible", "segregate", "forbidden"],
}

# --------------------------------------------------------------------------------------------
# Tables: (name, domain, description, columns, options)
# options: tenant (default True) -> organization_id NOT NULL
#          org_optional -> organization_id nullable (template when NULL) + firm_id
#          firm -> firm_id NOT NULL ; lib -> firm_id nullable (NULL = global library)
#          link -> composite PK on the given columns, no surrogate id
#          uniques, checks, no_audit (no created_by/updated_at)
# --------------------------------------------------------------------------------------------
T = []


def t(name, domain, desc, cols, **opt):
    T.append({"name": name, "domain": domain, "desc": desc, "cols": cols, "opt": opt})


P, S, L, E, CX, PR, DOC, RK, CO, OB, NC, AU, MR, HR, OP = (
    "platform", "standards", "library", "engagement", "context", "processes", "documents", "risks",
    "compliance", "objectives", "improvement", "audits", "review", "people", "operations")

DOMAINS = {
    P: "Platform, tenancy & access",
    S: "Standards & regulatory reference",
    L: "Firm library & kits",
    E: "Consulting engagements & certification",
    CX: "Context, scope & leadership",
    PR: "Processes",
    DOC: "Documented information & registers",
    RK: "Risks, hazards, aspects & emergencies",
    CO: "Compliance obligations",
    OB: "Objectives & indicators",
    NC: "Nonconformities, actions, incidents & complaints",
    AU: "Audits",
    MR: "Management review",
    HR: "People: competence, training, participation",
    OP: "Operations: suppliers, equipment, inspections, environment",
}

# ============================== PLATFORM ==============================
t("firms", P, "The consulting firm operating the platform (root tenant).", [
    "name:text:nn:", "legal_name:text::", "tax_id:text::Matricule fiscal", "country:char(2):nn def='TN':",
    "city:text::", "logo_file_id::fk=files:", "settings:jsonb:nn def='{}':Branding, numbering defaults, locale",
], tenant=False)
t("organizations", P, "Client companies (and the firm's own internal organization).", [
    "firm_id::nn fk=firms del=cascade:", "name:text:nn:", "legal_name:text::", "type:org_type:nn def='client':",
    "sector_id::fk=sectors:", "tax_id:text::", "address:text::", "city:text::", "country:char(2):nn def='TN':",
    "headcount:int::", "activity_description:text::", "logo_file_id::fk=files:",
    "status:record_status:nn def='active':", "onboarded_on:date::",
    "client_portal_enabled:boolean:nn def=true:Whether client users can log in",
    "firm_access:firm_access:nn def='full':Consultant access, set by the client (full, read_only, none)",
], tenant=False)
t("sites", P, "Physical locations of a client: head office, warehouse, worksites (chantiers), zones.", [
    "parent_site_id::fk=sites:Zone inside a site", "code:text::", "name:text:nn:", "type:site_type:nn:",
    "address:text::", "city:text::", "is_temporary:boolean:nn def=false:Worksite", "starts_on:date::",
    "ends_on:date::", "status:record_status:nn def='active':",
])
t("users", P, "Global identities (one person can be a consultant and/or belong to several client orgs).", [
    "email:text:nn uq:", "full_name:text:nn:", "phone:text::", "locale:text:nn def='fr':",
    "auth_subject:text:uq:External IdP subject", "is_platform_admin:boolean:nn def=false:",
    "status:record_status:nn def='active':", "last_login_at:timestamptz::",
], tenant=False, no_audit=True)
t("firm_members", P, "Consultants and admins of the firm.", [
    "firm_id::nn fk=firms del=cascade:", "user_id::nn fk=users del=cascade:", "role:firm_role:nn:",
    "title:text::", "is_active:boolean:nn def=true:",
], tenant=False, uniques=[("firm_id", "user_id")])
t("org_memberships", P, "A user's access to one client organization.", [
    "user_id::nn fk=users del=cascade:", "job_title:text::", "is_active:boolean:nn def=true:",
    "invited_by::fk=users:", "joined_at:timestamptz::",
], uniques=[("organization_id", "user_id")])
t("roles", P, "RBAC roles: system roles, custom firm roles, and custom roles a client creates for itself.", [
    "firm_id::fk=firms del=cascade:Custom firm role", "org_id::fk=organizations del=cascade:Custom client role",
    "scope:role_scope:nn:", "code:text:nn:",
    "name:text:nn:", "description:text::", "is_system:boolean:nn def=false:",
], tenant=False, uniques=[("firm_id", "org_id", "code")], checks=["NOT (firm_id IS NOT NULL AND org_id IS NOT NULL)"])
t("permissions", P, "Permission catalogue, e.g. documents.approve, hr.medical.read.", [
    "code:text:nn uq:", "module:text:nn:", "description:text::",
], tenant=False, no_audit=True)
t("role_permissions", P, "Permissions granted by a role.", [
    "role_id::nn fk=roles del=cascade:", "permission_id::nn fk=permissions del=cascade:",
], tenant=False, link=["role_id", "permission_id"])
t("membership_roles", P, "Roles held by a client member, optionally scoped to one process (process owner of PCS-ACH).", [
    "membership_id::nn fk=org_memberships del=cascade:", "role_id::nn fk=roles del=cascade:",
    "process_id::fk=processes del=cascade:Scope to one process",
], uniques=[("membership_id", "role_id", "process_id")])
t("subscriptions", P, "The client's own licence to use the platform, independent of any consulting engagement.", [
    "plan:subscription_plan:nn:", "status:subscription_status:nn def='active':", "seats:int::",
    "modules:text[]:nn def='{}':Enabled modules", "engagement_id::fk=engagements:Bundled with an engagement",
    "starts_on:date:nn def=CURRENT_DATE:", "ends_on:date::",
])
t("consultant_assignments", P, "Which consultants work on which client.", [
    "firm_member_id::nn fk=firm_members del=cascade:", "role:assignment_role:nn def='support':",
    "starts_on:date:nn def=CURRENT_DATE:", "ends_on:date::",
], uniques=[("organization_id", "firm_member_id", "starts_on")])
t("invitations", P, "Pending invitations to a firm or client org.", [
    "firm_id::nn fk=firms del=cascade:", "target_org_id::fk=organizations del=cascade:NULL = firm invite",
    "email:text:nn:", "role_id::nn fk=roles:", "token_hash:text:nn uq:", "expires_at:timestamptz:nn:",
    "accepted_at:timestamptz::", "invited_by::fk=users:",
], tenant=False)
t("files", P, "Binary objects in object storage (S3/MinIO).", [
    "firm_id::nn fk=firms del=cascade:", "org_id::fk=organizations del=cascade:",
    "storage_key:text:nn uq:", "filename:text:nn:", "mime_type:text:nn:", "size_bytes:bigint:nn:",
    "sha256:text:nn:", "virus_scanned_at:timestamptz::",
], tenant=False)
t("attachments", P, "Links a file to any record (evidence, photo, signed PV, certificate).", [
    "file_id::nn fk=files del=cascade:", "entity_type:text:nn:", "entity_id:uuid:nn:", "label:text::",
    "category:text::evidence, photo, signed_copy, certificate…",
])
t("comments", P, "Threaded comments on any record. firm_internal = hidden from client users.", [
    "entity_type:text:nn:", "entity_id:uuid:nn:", "parent_id::fk=comments del=cascade:", "body:text:nn:",
    "visibility:comment_visibility:nn def='shared':", "resolved_at:timestamptz::",
])
t("notifications", P, "In-app / email notifications.", [
    "user_id::nn fk=users del=cascade:", "org_id::fk=organizations del=cascade:", "type:text:nn:",
    "title:text:nn:", "body:text::", "entity_type:text::", "entity_id:uuid::", "read_at:timestamptz::",
    "emailed_at:timestamptz::",
], tenant=False, no_audit=True)
t("notification_preferences", P, "Per-user channel preferences by event type.", [
    "user_id::nn fk=users del=cascade:", "event_type:text:nn:", "in_app:boolean:nn def=true:",
    "email:boolean:nn def=true:", "digest:frequency::",
], tenant=False, no_audit=True, uniques=[("user_id", "event_type")])
t("activity_log", P, "Append-only audit trail of every change (who, what, before/after).", [
    "firm_id::nn fk=firms del=cascade:", "org_id::fk=organizations del=cascade:",
    "actor_user_id::fk=users:", "action:text:nn:create, update, approve, sign, export…",
    "entity_type:text:nn:", "entity_id:uuid::", "diff:jsonb::", "ip_address:inet::",
    "occurred_at:timestamptz:nn def=now():",
], tenant=False, no_audit=True)
t("import_jobs", P, "Excel/Word imports of a client's existing registers.", [
    "kind:text:nn:e.g. nonconformity_register, risk_manual, legal_watch", "file_id::nn fk=files:",
    "mapping:jsonb:nn def='{}':", "status:job_status:nn def='pending':", "stats:jsonb::", "errors:jsonb::",
    "finished_at:timestamptz::",
])
t("export_jobs", P, "Generated Word/Excel/PDF with the controlled-document header block.", [
    "document_template_id::fk=document_templates:", "entity_type:text:nn:", "entity_id:uuid::",
    "format:export_format:nn:", "file_id::fk=files:", "status:job_status:nn def='pending':",
])

# ============================== STANDARDS ==============================
t("sectors", S, "Activity sectors (agro-alimentaire, BTP, industrie, services, énergie…).", [
    "firm_id::fk=firms del=cascade:NULL = global", "code:text:nn:", "name:text:nn:",
], tenant=False, uniques=[("firm_id", "code")])
t("standards", S, "ISO 9001, ISO 14001, ISO 45001 (and future ones).", [
    "code:text:nn uq:e.g. ISO9001", "title:text:nn:", "system:qse_system:nn:",
], tenant=False)
t("standard_editions", S, "Editions: 9001:2015, 9001:2026, 14001:2015, 45001:2018…", [
    "standard_id::nn fk=standards del=cascade:", "edition:text:nn:", "published_on:date::",
    "transition_deadline:date::", "status:edition_status:nn def='active':",
], tenant=False, uniques=[("standard_id", "edition")])
t("clauses", S, "Clause tree per edition. Store titles + the firm's own paraphrase, not ISO text.", [
    "edition_id::nn fk=standard_editions del=cascade:", "parent_id::fk=clauses del=cascade:",
    "number:text:nn:e.g. 8.5.1", "title:text:nn:", "summary:text::Firm paraphrase",
    "documented_info:doc_info_requirement:nn def='none':", "sort_order:int:nn def=0:",
], tenant=False, uniques=[("edition_id", "number")])
t("clause_correspondences", S, "Maps clauses across editions (2015→2026) and across standards (harmonized structure).", [
    "from_clause_id::nn fk=clauses del=cascade:", "to_clause_id::nn fk=clauses del=cascade:",
    "type:correspondence_type:nn:", "note:text::",
], tenant=False, uniques=[("from_clause_id", "to_clause_id")])
t("regulatory_texts", S, "Legal library (JORT texts…). Global rows shared across every client.", [
    "firm_id::fk=firms del=cascade:NULL = global library", "jurisdiction:char(2):nn def='TN':",
    "type:regulatory_text_type:nn:", "reference:text:nn:e.g. Décret n°2000-1985", "title:text:nn:",
    "published_on:date::", "official_journal_ref:text::", "domain:text::", "systems:qse_system[]:nn def='{}':",
    "summary:text::", "source_url:text::", "status:regulatory_status:nn def='in_force':",
    "amended_by_id::fk=regulatory_texts:",
], tenant=False)
t("regulatory_requirements", S, "Individual obligations extracted from a text.", [
    "text_id::nn fk=regulatory_texts del=cascade:", "article:text::", "requirement:text:nn:",
    "applicability_criteria:text::", "expected_evidence:text::", "default_frequency:frequency::",
], tenant=False)
t("substance_compatibility_rules", S, "Hazardous substance storage compatibility matrix (by hazard class).", [
    "class_a:text:nn:", "class_b:text:nn:", "rule:compat_rule:nn:", "note:text::",
], tenant=False, uniques=[("class_a", "class_b")])

# ============================== LIBRARY ==============================
t("scoring_models", L, "Configurable scoring grids (G×P×D, F×G×M…). Firm default or org override.", [
    "firm_id::nn fk=firms del=cascade:", "org_id::fk=organizations del=cascade:NULL = firm default",
    "kind:scoring_kind:nn:", "name:text:nn:", "formula:text:nn:e.g. G*P*D", "version:int:nn def=1:",
    "is_default:boolean:nn def=false:",
], tenant=False)
t("scoring_dimensions", L, "Dimensions of a model: G, P, D, F, mastery, efficacy.", [
    "model_id::nn fk=scoring_models del=cascade:", "code:text:nn:", "name:text:nn:",
    "role:dimension_role:nn def='factor':", "sort_order:int:nn def=0:",
], tenant=False, uniques=[("model_id", "code")])
t("scoring_levels", L, "Levels of a dimension (1 = Très rare … 4 = Fréquent).", [
    "dimension_id::nn fk=scoring_dimensions del=cascade:", "value:numeric(6,2):nn:", "label:text:nn:",
    "description:text::",
], tenant=False, uniques=[("dimension_id", "value")])
t("scoring_bands", L, "Score ranges → priority (1–8 = Priorité 3, 16–64 = Priorité 1).", [
    "model_id::nn fk=scoring_models del=cascade:", "min_score:numeric(8,2):nn:",
    "max_score:numeric(8,2):nn:", "label:text:nn:", "priority:int:nn:", "color:text::",
    "requires_action:boolean:nn def=false:", "review_frequency:frequency::",
], tenant=False)
t("kits", L, "A certification kit: everything needed to start a client for given standards and sector.", [
    "firm_id::nn fk=firms del=cascade:", "name:text:nn:", "sector_id::fk=sectors:", "description:text::",
    "version:int:nn def=1:", "status:record_status:nn def='active':",
], tenant=False)
t("kit_editions", L, "Standards covered by a kit.", [
    "kit_id::nn fk=kits del=cascade:", "edition_id::nn fk=standard_editions del=cascade:",
], tenant=False, link=["kit_id", "edition_id"])
t("kit_items", L, "Contents of a kit (templates of every type).", [
    "kit_id::nn fk=kits del=cascade:", "item_type:kit_item_type:nn:", "item_id:uuid:nn:",
    "sort_order:int:nn def=0:",
], tenant=False)
t("document_templates", L, "Master procedures, forms, manuals with coding pattern and clause links.", [
    "firm_id::nn fk=firms del=cascade:", "category:doc_category:nn:", "type_code:text:nn:e.g. PRO, ID, MAN",
    "code_pattern:text:nn:e.g. {TYPE}-{PCS}-{SEQ:3}", "title:text:nn:", "content:jsonb::Rich-text body",
    "file_id::fk=files:DOCX/XLSX layout with header block", "version:int:nn def=1:",
    "status:record_status:nn def='active':",
], tenant=False)
t("template_clauses", L, "Clauses a template helps satisfy.", [
    "document_template_id::nn fk=document_templates del=cascade:", "clause_id::nn fk=clauses del=cascade:",
], tenant=False, link=["document_template_id", "clause_id"])
t("process_templates", L, "Standard process sheets per sector (PCS-QSE, PCS-ACH…).", [
    "firm_id::nn fk=firms del=cascade:", "sector_id::fk=sectors:", "code:text:nn:", "name:text:nn:",
    "type:process_type:nn:", "purpose:text::", "default_steps:jsonb:nn def='[]':",
], tenant=False)
t("indicator_templates", L, "Standard KPIs attached to process templates.", [
    "firm_id::nn fk=firms del=cascade:", "process_template_id::fk=process_templates del=cascade:",
    "name:text:nn:", "formula:text::", "unit:text::", "comparator:comparator::",
    "default_target:numeric(12,4)::", "frequency:frequency::",
], tenant=False)
t("risk_templates", L, "Library of typical risks, hazards and aspects by sector/activity.", [
    "firm_id::nn fk=firms del=cascade:", "sector_id::fk=sectors:", "kind:risk_kind:nn:",
    "activity:text::", "title:text:nn:", "cause:text::", "consequence:text::", "typical_controls:text::",
    "hazard_family:text::", "aspect:text::", "impact:text::",
], tenant=False)
t("clause_evidence_expectations", L, "What evidence the firm expects per clause (drives readiness).", [
    "firm_id::nn fk=firms del=cascade:", "clause_id::nn fk=clauses del=cascade:",
    "expected_evidence:text:nn:", "document_template_id::fk=document_templates:",
    "weight:numeric(5,2):nn def=1:",
], tenant=False)

# ============================== ENGAGEMENT ==============================
t("certification_bodies", E, "Bureau Veritas, TÜV, AFNOR…", [
    "firm_id::nn fk=firms del=cascade:", "name:text:nn:", "accreditation:text::", "contact:text::",
], tenant=False)
t("engagements", E, "A consulting mission for a client (one or several standards).", [
    "name:text:nn:", "status:engagement_status:nn def='prospect':", "kit_id::fk=kits:",
    "lead_consultant_id::fk=firm_members:", "certification_body_id::fk=certification_bodies:",
    "contract_ref:text::", "scope_summary:text::", "started_on:date::", "target_certification_on:date::",
    "closed_on:date::",
])
t("engagement_editions", E, "Standards targeted by an engagement.", [
    "engagement_id::nn fk=engagements del=cascade:", "edition_id::nn fk=standard_editions:",
], link=["engagement_id", "edition_id"])
t("engagement_milestones", E, "Phases and key dates of the mission.", [
    "engagement_id::nn fk=engagements del=cascade:", "phase:engagement_status:nn:", "name:text:nn:",
    "planned_on:date::", "done_on:date::", "status:milestone_status:nn def='planned':",
])
t("deliverables", E, "What the consultant owes the client.", [
    "engagement_id::nn fk=engagements del=cascade:", "milestone_id::fk=engagement_milestones:",
    "title:text:nn:", "document_id::fk=documents:", "owner_id::fk=firm_members:", "due_on:date::",
    "delivered_on:date::", "status:deliverable_status:nn def='todo':",
])
t("consultant_visits", E, "Visits / sessions with the client (time tracking + minutes).", [
    "engagement_id::nn fk=engagements del=cascade:", "firm_member_id::nn fk=firm_members:",
    "visit_on:date:nn:", "hours:numeric(5,2):nn def=0:", "mode:visit_mode:nn def='onsite':",
    "agenda:text::", "summary:text::", "next_steps:text::", "billable:boolean:nn def=true:",
])
t("gap_assessments", E, "Diagnostic against a standard edition.", [
    "engagement_id::fk=engagements:", "edition_id::nn fk=standard_editions:", "type:gap_type:nn:",
    "title:text:nn:", "assessed_on:date::", "assessor_id::fk=firm_members:",
    "status:plan_status:nn def='draft':", "overall_score:numeric(5,2)::",
])
t("gap_assessment_items", E, "One line per clause: status, evidence, recommendation.", [
    "gap_assessment_id::nn fk=gap_assessments del=cascade:", "clause_id::nn fk=clauses:",
    "status:gap_status:nn def='not_assessed':", "score:numeric(3,2)::0..1", "finding:text::",
    "evidence:text::", "recommendation:text::",
], uniques=[("gap_assessment_id", "clause_id")])
t("readiness_snapshots", E, "Computed certification readiness per edition, kept as history.", [
    "edition_id::nn fk=standard_editions:", "computed_at:timestamptz:nn def=now():",
    "overall_score:numeric(5,2):nn:", "by_clause:jsonb:nn:", "open_major_nc:int:nn def=0:",
    "overdue_actions:int:nn def=0:",
], no_audit=True)
t("certificates", E, "Certificates obtained by the client.", [
    "edition_id::nn fk=standard_editions:", "certification_body_id::fk=certification_bodies:",
    "number:text::", "scope:text::", "issued_on:date::", "expires_on:date::",
    "status:certificate_status:nn def='valid':",
])

# ============================== CONTEXT ==============================
t("management_systems", CX, "The client's (integrated) management system: scope and boundaries (4.3).", [
    "name:text:nn:", "scope_statement:text::", "boundaries:text::", "document_id::fk=documents:",
    "approved_on:date::",
])
t("management_system_editions", CX, "Standards the system covers.", [
    "management_system_id::nn fk=management_systems del=cascade:", "edition_id::nn fk=standard_editions:",
], link=["management_system_id", "edition_id"])
t("clause_exclusions", CX, "Non-applicable requirements with justification.", [
    "management_system_id::nn fk=management_systems del=cascade:", "clause_id::nn fk=clauses:",
    "justification:text:nn:",
], uniques=[("management_system_id", "clause_id")])
t("context_issues", CX, "Internal/external issues, SWOT (MAN-QSE-001).", [
    "nature:issue_nature:nn:", "swot_type:swot_type::", "category:text::PESTEL / 5M bucket",
    "title:text:nn:", "description:text::", "impact:text::", "systems:qse_system[]:nn def='{}':",
    "process_id::fk=processes:", "is_active:boolean:nn def=true:", "reviewed_on:date::",
])
t("interested_parties", CX, "Relevant interested parties (PIP).", [
    "name:text:nn:", "category:text::", "nature:issue_nature:nn:", "influence:int::1..3",
    "interest:int::1..3", "is_relevant:boolean:nn def=true:",
])
t("party_requirements", CX, "Needs & expectations; flagged ones become compliance obligations.", [
    "party_id::nn fk=interested_parties del=cascade:", "requirement:text:nn:",
    "is_compliance_obligation:boolean:nn def=false:", "how_addressed:text::", "process_id::fk=processes:",
])
t("policy_axes", CX, "Strategic axes of the QSE policy that objectives hang from.", [
    "policy_document_id::fk=documents:", "code:text::", "title:text:nn:", "sort_order:int:nn def=0:",
])

# ============================== PROCESSES ==============================
t("processes", PR, "Process map entries with the full process sheet header.", [
    "code:text:nn:e.g. PCS-QSE", "name:text:nn:", "type:process_type:nn:", "parent_id::fk=processes:",
    "owner_membership_id::fk=org_memberships:Pilote", "deputy_membership_id::fk=org_memberships:",
    "purpose:text::Finalité", "scope:text::", "start_trigger:text::", "end_output:text::",
    "human_resources:text::", "material_resources:text::", "monitoring_methods:text::",
    "sheet_document_id::fk=documents:", "template_id::fk=process_templates:",
    "sort_order:int:nn def=0:", "is_active:boolean:nn def=true:",
], uniques=[("organization_id", "code")])
t("process_steps", PR, "Déroulement: inputs → activity → responsible → outputs.", [
    "process_id::nn fk=processes del=cascade:", "step_no:int:nn:", "inputs:text::", "activity:text:nn:",
    "responsible_position_id::fk=positions:", "responsible_text:text::", "interactions:text::",
    "outputs:text::", "description:text::",
], uniques=[("process_id", "step_no")])
t("process_step_documents", PR, "Documents associated with a step.", [
    "step_id::nn fk=process_steps del=cascade:", "document_id::nn fk=documents del=cascade:",
], link=["step_id", "document_id"])
t("process_interactions", PR, "Flows between processes (cartographie).", [
    "from_process_id::nn fk=processes del=cascade:", "to_process_id::nn fk=processes del=cascade:",
    "flow:text::",
])
t("process_clauses", PR, "Clauses each process covers.", [
    "process_id::nn fk=processes del=cascade:", "clause_id::nn fk=clauses:",
], link=["process_id", "clause_id"])
t("process_reviews", PR, "Periodic process performance review (tableau de bord PCS).", [
    "process_id::nn fk=processes del=cascade:", "period_start:date:nn:", "period_end:date:nn:",
    "reviewer_membership_id::fk=org_memberships:", "summary:text::", "conclusion:review_conclusion::",
])

# ============================== DOCUMENTS ==============================
t("document_types", DOC, "Per-client coding prefixes (PLT, PCS, PRO, INT, MAN, PLN, LST, ID, DOC).", [
    "code:text:nn:", "label:text:nn:", "category:doc_category:nn:",
    "requires_approval:boolean:nn def=true:", "default_review_months:int::",
    "retention_months:int::",
], uniques=[("organization_id", "code")])
t("documents", DOC, "Master list of documented information (ID-QSE-015).", [
    "code:text:nn:", "title:text:nn:", "document_type_id::nn fk=document_types:", "process_id::fk=processes:",
    "owner_membership_id::fk=org_memberships:", "status:doc_status:nn def='draft':",
    "current_version_id::fk=document_versions:", "confidentiality:confidentiality:nn def='internal':",
    "review_months:int::", "next_review_on:date::", "retention_months:int::",
    "source:doc_source:nn def='created':", "external_origin:text::For external documents",
    "template_id::fk=document_templates:", "template_version:int::Template version it was copied from",
    "legacy_path:text::Where it lived before import",
], uniques=[("organization_id", "code")])
t("document_versions", DOC, "Revisions with content/file and change history.", [
    "document_id::nn fk=documents del=cascade:", "revision:text:nn:e.g. 00, 01", "version_no:int:nn:",
    "change_summary:text::Objet de la modification", "content:jsonb::", "file_id::fk=files:",
    "status:version_status:nn def='draft':", "effective_on:date::", "superseded_on:date::",
], uniques=[("document_id", "version_no")])
t("document_approvals", DOC, "Rédacteur / vérificateur / approbateur circuit with e-signature.", [
    "version_id::nn fk=document_versions del=cascade:", "step:approval_step:nn:",
    "assignee_membership_id::fk=org_memberships:", "assignee_firm_member_id::fk=firm_members:",
    "decision:approval_decision:nn def='pending':", "comment:text::", "decided_at:timestamptz::",
    "signature_hash:text::", "sort_order:int:nn def=0:",
])
t("distribution_points", DOC, "Points de diffusion.", [
    "number:text:nn:", "location:text:nn:", "functions:text::",
])
t("document_distributions", DOC, "Where each version is distributed, for application or information.", [
    "version_id::nn fk=document_versions del=cascade:", "distribution_point_id::nn fk=distribution_points:",
    "purpose:distribution_purpose:nn def='application':", "distributed_at:timestamptz::",
])
t("document_acknowledgements", DOC, "Read-and-understood confirmations.", [
    "version_id::nn fk=document_versions del=cascade:", "membership_id::fk=org_memberships:",
    "employee_id::fk=employees:", "acknowledged_at:timestamptz:nn def=now():",
])
t("document_clauses", DOC, "Clauses a document satisfies (feeds readiness).", [
    "document_id::nn fk=documents del=cascade:", "clause_id::nn fk=clauses:",
], link=["document_id", "clause_id"])
t("document_sequences", DOC, "Counters for automatic codes (PRO-QSE-007 → next is 008).", [
    "document_type_id::nn fk=document_types del=cascade:", "process_id::fk=processes del=cascade:",
    "last_value:int:nn def=0:",
], uniques=[("organization_id", "document_type_id", "process_id")])
t("register_definitions", DOC, "Configurable registers/forms for the long tail (fiche d'intervention, PV de réunion…).", [
    "firm_id::nn fk=firms del=cascade:", "org_id::fk=organizations del=cascade:NULL = firm template",
    "code:text::", "name:text:nn:", "description:text::", "schema:jsonb:nn:Field definitions (JSON Schema)",
    "document_id::fk=documents:Controlled form it implements", "process_id::fk=processes:",
    "numbering_pattern:text::",
], tenant=False)
t("register_entries", DOC, "Rows/records of a configurable register.", [
    "definition_id::nn fk=register_definitions del=cascade:", "number:text::", "data:jsonb:nn:",
    "site_id::fk=sites:", "process_id::fk=processes:", "project_id::fk=projects:",
    "recorded_on:date:nn def=CURRENT_DATE:", "status:text::",
])
t("change_requests", DOC, "Management of change (ID-QSE-020 / PRO-QSE-005).", [
    "number:text:nn:", "title:text:nn:", "type:change_type:nn:", "description:text::", "reason:text::",
    "risk_assessment:text::", "requested_by::fk=org_memberships:", "approved_by::fk=org_memberships:",
    "status:change_status:nn def='requested':", "planned_on:date::", "implemented_on:date::",
], uniques=[("organization_id", "number")])
t("change_impacts", DOC, "Records impacted by a change (documents, processes, risks…).", [
    "change_request_id::nn fk=change_requests del=cascade:", "entity_type:text:nn:", "entity_id:uuid:nn:",
    "note:text::",
])
t("knowledge_items", DOC, "Organizational knowledge register (7.1.6).", [
    "process_id::fk=processes:", "domain:text::", "title:text:nn:", "description:text::",
    "holder_employee_id::fk=employees:", "source:direction::", "capture_method:text::",
    "document_id::fk=documents:", "is_critical:boolean:nn def=false:", "sharing_method:text::",
    "reviewed_on:date::",
])

# ============================== RISKS ==============================
t("activities", RK, "Units of analysis: Administration, Chantier électricité, Routier…", [
    "site_id::fk=sites:", "process_id::fk=processes:", "name:text:nn:", "type:activity_type:nn:",
    "description:text::",
])
t("risk_assessments", RK, "A risk / OHS / environmental manual (MAN-QSE-002/003/004).", [
    "kind:assessment_kind:nn:", "scoring_model_id::nn fk=scoring_models:", "title:text:nn:",
    "document_id::fk=documents:", "year:int::", "status:plan_status:nn def='draft':",
    "reviewed_on:date::",
])
t("risk_items", RK, "One risk, opportunity, OHS hazard or environmental aspect.", [
    "assessment_id::nn fk=risk_assessments del=cascade:", "kind:risk_kind:nn:", "reference:text::",
    "activity_id::fk=activities:", "process_id::fk=processes:", "context_issue_id::fk=context_issues:",
    "interested_party_id::fk=interested_parties:", "title:text:nn:", "cause_category:cause_category::",
    "cause:text::", "consequence:text::", "existing_controls:text::",
    "owner_membership_id::fk=org_memberships:", "current_score:numeric(8,2)::Denormalized latest",
    "current_band_id::fk=scoring_bands:", "is_active:boolean:nn def=true:",
    "template_id::fk=risk_templates:",
])
t("ohs_hazard_details", RK, "OHS-specific fields (ISO 45001 6.1.2).", [
    "risk_item_id::nn fk=risk_items del=cascade uq:", "task:text::", "hazard_family:text::",
    "routine:routine_type:nn def='routine':", "exposed_persons:text::", "exposed_count:int::",
    "regulatory_requirement_id::fk=regulatory_requirements:",
])
t("env_aspect_details", RK, "Environmental fields (ISO 14001 6.1.2) incl. life-cycle perspective.", [
    "risk_item_id::nn fk=risk_items del=cascade uq:", "aspect:text:nn:", "impact:text:nn:",
    "operating_condition:env_condition:nn def='normal':", "lifecycle_stage:lifecycle_stage::",
    "control_level:control_level:nn def='control':", "is_significant:boolean:nn def=false:",
    "significance_reason:text::", "regulatory_requirement_id::fk=regulatory_requirements:",
])
t("risk_evaluations", RK, "Initial / residual / re-evaluation with score, band, mastery, efficacy.", [
    "risk_item_id::nn fk=risk_items del=cascade:", "phase:eval_phase:nn:", "evaluated_on:date:nn:",
    "evaluator_membership_id::fk=org_memberships:", "score:numeric(8,2):nn:", "band_id::fk=scoring_bands:",
    "mastery_level:numeric(4,2)::", "efficacy:numeric(3,2)::0 / 0.5 / 1", "notes:text::",
])
t("risk_evaluation_scores", RK, "Value per dimension (G=3, P=2, D=4).", [
    "evaluation_id::nn fk=risk_evaluations del=cascade:", "dimension_id::nn fk=scoring_dimensions:",
    "value:numeric(6,2):nn:",
], link=["evaluation_id", "dimension_id"])
t("emergency_situations", RK, "Potential emergencies and response (PLN-QSE-002).", [
    "site_id::fk=sites:", "risk_item_id::fk=risk_items:", "title:text:nn:", "scenario:text::",
    "consequences:text::", "response_document_id::fk=documents:", "resources:text::",
    "responsible_membership_id::fk=org_memberships:",
])
t("emergency_drills", RK, "Opérations blanches: plan, execution, PV, efficacy.", [
    "emergency_situation_id::nn fk=emergency_situations:", "site_id::fk=sites:", "planned_on:date:nn:",
    "performed_on:date::", "participants_count:int::", "duration_minutes:int::", "observations:text::",
    "efficacy:numeric(3,2)::", "status:session_status:nn def='planned':",
])
t("hazardous_substances", RK, "Chemical inventory with SDS and storage class.", [
    "site_id::fk=sites:", "name:text:nn:", "supplier_id::fk=suppliers:", "usage:text::",
    "hazard_classes:text[]:nn def='{}':GHS pictograms", "sds_file_id::fk=files:", "sds_revision_on:date::",
    "storage_location:text::", "max_quantity:numeric(12,3)::", "unit:text::",
])

# ============================== COMPLIANCE ==============================
t("compliance_obligations", CO, "Applicable requirements for this client (legal + other).", [
    "source:obligation_source:nn def='legal':", "regulatory_text_id::fk=regulatory_texts:",
    "regulatory_requirement_id::fk=regulatory_requirements:", "party_requirement_id::fk=party_requirements:",
    "title:text:nn:", "requirement:text::", "system:qse_system:nn:", "domain:text::",
    "is_applicable:boolean:nn def=true:", "applicability_note:text::",
    "evaluation_frequency:frequency:nn def='annual':", "owner_membership_id::fk=org_memberships:",
    "process_id::fk=processes:", "risk_if_noncompliant:text::", "next_evaluation_on:date::",
    "last_status:compliance_status:nn def='not_evaluated':",
])
t("compliance_evaluations", CO, "Evaluation of compliance (9.1.2 of 14001/45001).", [
    "obligation_id::nn fk=compliance_obligations del=cascade:", "evaluated_on:date:nn:",
    "status:compliance_status:nn:", "evidence:text::", "evaluator_membership_id::fk=org_memberships:",
    "evaluator_firm_member_id::fk=firm_members:",
])

# ============================== OBJECTIVES ==============================
t("objectives", OB, "QSE objectives per policy axis (ID-QSE-002).", [
    "policy_axis_id::fk=policy_axes:", "process_id::fk=processes:", "year:int:nn:", "code:text::",
    "title:text:nn:", "description:text::", "owner_membership_id::fk=org_memberships:", "resources:text::",
    "due_on:date::", "completion_level:numeric(3,2)::0 / 0.5 / 1", "efficacy:numeric(3,2)::",
    "status:objective_status:nn def='planned':",
])
t("indicators", OB, "KPIs per process, optionally tied to an objective.", [
    "process_id::fk=processes:", "objective_id::fk=objectives:", "code:text::", "name:text:nn:",
    "definition:text::", "formula:text::", "unit:text::", "comparator:comparator:nn def='gte':",
    "target_value:numeric(14,4)::", "target_value_max:numeric(14,4)::",
    "frequency:frequency:nn def='monthly':", "owner_membership_id::fk=org_memberships:",
    "data_source:text::", "template_id::fk=indicator_templates:", "is_active:boolean:nn def=true:",
])
t("indicator_measurements", OB, "Period values with analysis (fiche suivi indicateur).", [
    "indicator_id::nn fk=indicators del=cascade:", "period_start:date:nn:", "period_end:date:nn:",
    "value:numeric(14,4)::", "numerator:numeric(14,4)::", "denominator:numeric(14,4)::",
    "target_snapshot:numeric(14,4)::", "is_met:boolean::", "analysis:text::",
    "entered_by_membership_id::fk=org_memberships:",
], uniques=[("indicator_id", "period_start")])

# ============================== IMPROVEMENT ==============================
t("customers", NC, "Client's customers (for complaints and satisfaction).", [
    "name:text:nn:", "type:text::", "contact:text::", "city:text::",
])
t("projects", OP, "Worksites / projects / contracts (chantiers).", [
    "customer_id::fk=customers:", "site_id::fk=sites:", "code:text::", "name:text:nn:", "type:text::",
    "starts_on:date::", "ends_on:date::", "status:project_status:nn def='planned':",
    "manager_membership_id::fk=org_memberships:",
])
t("customer_surveys", NC, "Customer satisfaction measurements (9.1.2).", [
    "customer_id::fk=customers:", "project_id::fk=projects:", "sent_on:date::", "answered_on:date::",
    "score:numeric(5,2)::", "responses:jsonb::", "comment:text::",
])
t("complaints", NC, "Customer complaints (réclamations).", [
    "number:text:nn:", "customer_id::fk=customers:", "project_id::fk=projects:", "received_on:date:nn:",
    "channel:text::", "description:text:nn:", "is_justified:boolean::", "response:text::",
    "responded_on:date::", "status:complaint_status:nn def='received':",
], uniques=[("organization_id", "number")])
t("incidents", NC, "Work accidents, near-misses, environmental incidents.", [
    "number:text:nn:", "type:incident_type:nn:", "site_id::fk=sites:", "project_id::fk=projects:",
    "occurred_at:timestamptz:nn:", "location:text::", "description:text:nn:",
    "employee_id::fk=employees:Person involved (restricted access)", "injury_nature:text::",
    "lost_days:int::", "severity:int::1..4", "immediate_actions:text::",
    "reported_by_membership_id::fk=org_memberships:", "authority_declared_on:date::",
    "investigation:text::", "status:incident_status:nn def='reported':",
], uniques=[("organization_id", "number")])
t("nonconformities", NC, "Single NC register for every origin (ID-QSE-012, all tabs).", [
    "number:text:nn:", "title:text:nn:", "description:text::", "detected_on:date:nn:",
    "source:nc_source:nn:", "severity:nc_severity:nn def='minor':", "process_id::fk=processes:",
    "site_id::fk=sites:", "project_id::fk=projects:", "supplier_id::fk=suppliers:",
    "detected_by_membership_id::fk=org_memberships:", "detected_by_firm_member_id::fk=firm_members:",
    "owner_membership_id::fk=org_memberships:", "containment:text::Immediate correction",
    "rca_method:rca_method::", "rca:jsonb::5 whys / Ishikawa content", "root_cause:text::",
    "status:nc_status:nn def='open':", "closed_on:date::", "efficacy:numeric(3,2)::",
    "efficacy_verified_on:date::",
    "audit_finding_id::fk=audit_findings:", "gap_assessment_item_id::fk=gap_assessment_items:",
    "indicator_measurement_id::fk=indicator_measurements:", "complaint_id::fk=complaints:",
    "incident_id::fk=incidents:", "emergency_drill_id::fk=emergency_drills:",
    "compliance_evaluation_id::fk=compliance_evaluations:", "inspection_result_id::fk=inspection_results:",
    "management_review_id::fk=management_reviews:", "worker_meeting_id::fk=worker_meetings:",
    "register_entry_id::fk=register_entries:",
], uniques=[("organization_id", "number")], checks=[
    "num_nonnulls(audit_finding_id, gap_assessment_item_id, indicator_measurement_id, complaint_id, "
    "incident_id, emergency_drill_id, compliance_evaluation_id, inspection_result_id, management_review_id, "
    "worker_meeting_id, register_entry_id) <= 1"])
t("nonconformity_clauses", NC, "Clauses concerned by an NC.", [
    "nonconformity_id::nn fk=nonconformities del=cascade:", "clause_id::nn fk=clauses:",
], link=["nonconformity_id", "clause_id"])
t("actions", NC, "THE action plan: every correction, corrective action, risk treatment, objective action…", [
    "number:text:nn:", "title:text:nn:", "description:text::", "type:action_type:nn:",
    "source:action_source:nn def='standalone':", "priority:priority:nn def='medium':",
    "status:action_status:nn def='planned':", "due_on:date::", "completed_on:date::",
    "completion_level:numeric(3,2):nn def=0:0 / 0.5 / 1", "resources:text::", "cost:numeric(12,2)::",
    "efficacy_criteria:text::", "efficacy_due_on:date::", "efficacy:numeric(3,2)::",
    "efficacy_verified_by::fk=org_memberships:", "efficacy_verified_on:date::",
    "nonconformity_id::fk=nonconformities del=cascade:", "risk_item_id::fk=risk_items:",
    "objective_id::fk=objectives:", "audit_finding_id::fk=audit_findings:",
    "management_review_decision_id::fk=management_review_decisions:",
    "gap_assessment_item_id::fk=gap_assessment_items:", "compliance_evaluation_id::fk=compliance_evaluations:",
    "change_request_id::fk=change_requests:", "worker_meeting_id::fk=worker_meetings:",
    "emergency_drill_id::fk=emergency_drills:", "equipment_check_id::fk=equipment_checks:",
    "inspection_id::fk=inspections:",
], uniques=[("organization_id", "number")], checks=[
    "num_nonnulls(nonconformity_id, risk_item_id, objective_id, audit_finding_id, management_review_decision_id, "
    "gap_assessment_item_id, compliance_evaluation_id, change_request_id, worker_meeting_id, emergency_drill_id, "
    "equipment_check_id, inspection_id) <= 1"])
t("action_owners", NC, "Several owners per action (\"R QSE + D technique\").", [
    "action_id::nn fk=actions del=cascade:", "membership_id::nn fk=org_memberships del=cascade:",
    "is_lead:boolean:nn def=false:",
], link=["action_id", "membership_id"])
t("action_updates", NC, "Progress log on an action.", [
    "action_id::nn fk=actions del=cascade:", "note:text:nn:", "completion_level:numeric(3,2)::",
])

# ============================== AUDITS ==============================
t("audit_programs", AU, "Annual internal audit programme (ID-QSE-017).", [
    "year:int:nn:", "title:text::", "document_id::fk=documents:", "criteria:text::",
    "status:plan_status:nn def='draft':", "approved_by::fk=org_memberships:", "approved_on:date::",
], uniques=[("organization_id", "year")])
t("audit_program_items", AU, "Planned audits per process and period.", [
    "program_id::nn fk=audit_programs del=cascade:", "process_id::fk=processes:", "clause_refs:text::",
    "planned_month:int::1..12", "planned_week:int::1..5", "audit_id::fk=audits:Audit that realised it",
])
t("audits", AU, "Any audit: internal, mock, supplier, certification stages.", [
    "type:audit_type:nn:", "title:text:nn:", "objectives:text::", "scope:text::", "criteria:text::",
    "supplier_id::fk=suppliers:", "certification_body_id::fk=certification_bodies:",
    "engagement_id::fk=engagements:", "planned_start:date::", "planned_end:date::", "actual_start:date::",
    "actual_end:date::", "status:audit_status:nn def='planned':", "conclusion:text::",
    "certification_recommended:boolean::", "report_document_id::fk=documents:",
])
t("audit_editions", AU, "Standards audited.", [
    "audit_id::nn fk=audits del=cascade:", "edition_id::nn fk=standard_editions:",
], link=["audit_id", "edition_id"])
t("audit_team_members", AU, "Auditors: client staff, consultants or external auditors.", [
    "audit_id::nn fk=audits del=cascade:", "role:audit_role:nn:", "membership_id::fk=org_memberships:",
    "firm_member_id::fk=firm_members:", "external_name:text::",
], checks=["num_nonnulls(membership_id, firm_member_id, external_name) = 1"])
t("audit_plan_slots", AU, "Audit plan: time slots per process/site/clauses.", [
    "audit_id::nn fk=audits del=cascade:", "starts_at:timestamptz:nn:", "ends_at:timestamptz::",
    "process_id::fk=processes:", "site_id::fk=sites:", "clause_refs:text::", "auditees:text::",
    "team_member_id::fk=audit_team_members:",
])
t("audit_checklist_items", AU, "Questions, evidence and result per clause.", [
    "audit_id::nn fk=audits del=cascade:", "clause_id::fk=clauses:", "process_id::fk=processes:",
    "question:text:nn:", "result:checklist_result::", "evidence:text::", "notes:text::",
    "sort_order:int:nn def=0:",
])
t("audit_findings", AU, "Findings; NCs are raised from them.", [
    "audit_id::nn fk=audits del=cascade:", "number:text::", "type:finding_type:nn:", "clause_id::fk=clauses:",
    "process_id::fk=processes:", "site_id::fk=sites:", "requirement:text::", "description:text:nn:",
    "evidence:text::", "status:finding_status:nn def='open':", "response_due_on:date::",
])

# ============================== MANAGEMENT REVIEW ==============================
t("management_reviews", MR, "Revue de direction.", [
    "number:text::", "planned_on:date::", "held_on:date::", "period_start:date::", "period_end:date::",
    "status:review_status:nn def='planned':", "chair_membership_id::fk=org_memberships:",
    "minutes_document_id::fk=documents:", "next_review_on:date::",
])
t("management_review_participants", MR, "Attendees.", [
    "review_id::nn fk=management_reviews del=cascade:", "membership_id::fk=org_memberships:",
    "firm_member_id::fk=firm_members:", "external_name:text::", "role:text::",
])
t("management_review_inputs", MR, "Mandatory inputs, auto-compiled from the other modules as snapshots.", [
    "review_id::nn fk=management_reviews del=cascade:", "input_type:mr_input:nn:", "summary:text::",
    "data_snapshot:jsonb::Frozen figures at review time", "prepared_by::fk=org_memberships:",
], uniques=[("review_id", "input_type")])
t("management_review_decisions", MR, "Outputs: decisions that become actions.", [
    "review_id::nn fk=management_reviews del=cascade:", "output_type:mr_output:nn:",
    "description:text:nn:", "owner_membership_id::fk=org_memberships:", "due_on:date::",
])

# ============================== PEOPLE ==============================
t("positions", HR, "Job positions / fiches fonction; reports_to builds the organigram.", [
    "code:text::", "title:text:nn:", "process_id::fk=processes:", "reports_to_id::fk=positions:",
    "mission:text::", "responsibilities:text::", "qse_responsibilities:text::", "authorities:text::",
    "document_id::fk=documents:", "headcount:int::",
])
t("employees", HR, "Staff (not all are platform users). Minimal personal data.", [
    "membership_id::fk=org_memberships uq:", "position_id::fk=positions:", "site_id::fk=sites:",
    "employee_number:text::", "full_name:text:nn:", "hire_date:date::", "end_date:date::",
    "contract_type:contract_type::", "status:employee_status:nn def='active':",
])
t("competencies", HR, "Competency catalogue incl. authorizations (habilitation électrique).", [
    "name:text:nn:", "category:competency_category:nn:", "requires_certificate:boolean:nn def=false:",
    "validity_months:int::",
])
t("position_competencies", HR, "Required competencies per position.", [
    "position_id::nn fk=positions del=cascade:", "competency_id::nn fk=competencies del=cascade:",
    "required_level:int:nn def=1:",
], link=["position_id", "competency_id"])
t("competency_evaluations", HR, "Competency assessments (cadre / chantier grids).", [
    "employee_id::nn fk=employees del=cascade:", "competency_id::nn fk=competencies:",
    "evaluated_on:date:nn:", "level:int:nn:", "evaluator_membership_id::fk=org_memberships:", "comment:text::",
])
t("employee_qualifications", HR, "Certificates/authorizations with expiry.", [
    "employee_id::nn fk=employees del=cascade:", "competency_id::nn fk=competencies:", "reference:text::",
    "issued_on:date::", "expires_on:date::", "issuer_supplier_id::fk=suppliers:",
])
t("training_needs", HR, "Identified training needs.", [
    "employee_id::fk=employees del=cascade:", "position_id::fk=positions:", "competency_id::fk=competencies:",
    "title:text:nn:", "source:need_source:nn:", "priority:priority:nn def='medium':", "year:int:nn:",
    "status:request_status:nn def='submitted':",
])
t("training_plans", HR, "Annual training & awareness programme.", [
    "year:int:nn:", "status:plan_status:nn def='draft':", "document_id::fk=documents:", "budget:numeric(12,2)::",
], uniques=[("organization_id", "year")])
t("training_sessions", HR, "Trainings, awareness sessions, inductions, toolbox talks.", [
    "plan_id::fk=training_plans:", "need_id::fk=training_needs:", "kind:session_kind:nn:",
    "title:text:nn:", "competency_id::fk=competencies:", "provider_supplier_id::fk=suppliers:",
    "trainer:text::", "site_id::fk=sites:", "planned_start:date::", "planned_end:date::",
    "performed_on:date::", "duration_hours:numeric(6,2)::", "cost:numeric(12,2)::",
    "status:session_status:nn def='planned':", "efficacy:numeric(3,2)::", "evaluation_summary:text::",
])
t("training_attendances", HR, "Attendance sheet, signatures and evaluations.", [
    "session_id::nn fk=training_sessions del=cascade:", "employee_id::nn fk=employees del=cascade:",
    "attended:boolean:nn def=false:", "signed:boolean:nn def=false:", "score:numeric(5,2)::",
    "hot_evaluation:int::", "cold_evaluation:int::",
], link=["session_id", "employee_id"])
t("recruitment_requests", HR, "Recruitment needs.", [
    "position_id::fk=positions:", "reason:text::", "headcount:int:nn def=1:",
    "requested_by::fk=org_memberships:", "requested_on:date:nn def=CURRENT_DATE:",
    "status:request_status:nn def='draft':",
])
t("onboarding_plans", HR, "Integration plan for new hires.", [
    "employee_id::nn fk=employees del=cascade:", "tutor_employee_id::fk=employees:", "starts_on:date::",
    "steps:jsonb:nn def='[]':", "completed_on:date::",
])
t("medical_visits", HR, "Occupational health follow-up: dates and fitness only, never diagnoses.", [
    "employee_id::nn fk=employees del=cascade:", "visit_type:medical_visit_type:nn:", "visit_on:date::",
    "next_due_on:date::", "fitness:fitness:nn def='pending':",
])
t("ppe_issues", HR, "PPE / work clothing issued.", [
    "employee_id::nn fk=employees del=cascade:", "item:text:nn:", "size:text::", "quantity:int:nn def=1:",
    "issued_on:date:nn:", "renewal_due_on:date::",
])
t("communication_plan_items", HR, "Internal/external communication plan (ID-QSE-016).", [
    "subject:text:nn:", "direction:direction:nn:", "audience:text::", "channel:text::",
    "frequency:frequency::", "sender_membership_id::fk=org_memberships:", "process_id::fk=processes:",
    "system:qse_system::",
])
t("communication_records", HR, "Evidence that a communication happened.", [
    "plan_item_id::fk=communication_plan_items:", "communicated_on:date:nn:", "summary:text::",
    "audience_count:int::",
])
t("worker_meetings", HR, "Worker participation & consultation (ISO 45001 5.4).", [
    "planned_on:date::", "held_on:date::", "topics:text::", "minutes:text::",
    "status:session_status:nn def='planned':",
])
t("worker_meeting_participants", HR, "Attendees.", [
    "meeting_id::nn fk=worker_meetings del=cascade:", "employee_id::nn fk=employees del=cascade:",
    "role:meeting_role:nn def='worker_representative':",
], link=["meeting_id", "employee_id"])
t("visitor_logs", HR, "Visitor register with safety briefing.", [
    "site_id::fk=sites:", "visitor_name:text:nn:", "company:text::", "purpose:text::",
    "host_employee_id::fk=employees:", "arrived_at:timestamptz:nn:", "left_at:timestamptz::",
    "safety_briefing_done:boolean:nn def=false:", "ppe_provided:boolean:nn def=false:",
])

# ============================== OPERATIONS ==============================
t("suppliers", OP, "Suppliers and external providers (8.4).", [
    "name:text:nn:", "category:supplier_category:nn:", "is_critical:boolean:nn def=false:",
    "status:supplier_decision:nn def='pending':", "contact_name:text::", "email:text::", "phone:text::",
    "city:text::", "approved_on:date::", "next_evaluation_on:date::",
])
t("supplier_criteria", OP, "Weighted selection/evaluation criteria.", [
    "kind:evaluation_kind:nn:", "name:text:nn:", "weight:numeric(5,2):nn def=1:", "sort_order:int:nn def=0:",
])
t("supplier_evaluations", OP, "Selection and periodic evaluations.", [
    "supplier_id::nn fk=suppliers del=cascade:", "kind:evaluation_kind:nn:", "evaluated_on:date:nn:",
    "evaluator_membership_id::fk=org_memberships:", "total_score:numeric(6,2)::",
    "decision:supplier_decision:nn:", "comment:text::",
])
t("supplier_evaluation_scores", OP, "Score per criterion.", [
    "evaluation_id::nn fk=supplier_evaluations del=cascade:", "criterion_id::nn fk=supplier_criteria:",
    "score:numeric(6,2):nn:",
], link=["evaluation_id", "criterion_id"])
t("equipment", OP, "Measuring instruments, lifting gear, extinguishers, installations, vehicles.", [
    "site_id::fk=sites:", "category:equipment_category:nn:", "code:text::", "name:text:nn:", "brand:text::",
    "model:text::", "serial_number:text::", "location:text::", "status:equipment_status:nn def='in_service':",
    "commissioned_on:date::", "is_regulated:boolean:nn def=false:Subject to regulatory inspection",
])
t("equipment_check_plans", OP, "Recurring calibration / maintenance / regulatory inspection schedules.", [
    "equipment_id::nn fk=equipment del=cascade:", "check_type:check_type:nn:", "frequency_months:int:nn:",
    "provider_supplier_id::fk=suppliers:", "next_due_on:date::", "is_active:boolean:nn def=true:",
])
t("equipment_checks", OP, "Performed checks with result and certificate.", [
    "equipment_id::nn fk=equipment del=cascade:", "plan_id::fk=equipment_check_plans:",
    "check_type:check_type:nn:", "due_on:date::", "performed_on:date::", "provider_supplier_id::fk=suppliers:",
    "performed_by:text::", "result:check_result:nn def='pending':", "certificate_ref:text::",
    "cost:numeric(12,2)::",
])
t("equipment_check_reservations", OP, "Reservations from regulatory inspections (ID-GSM-005).", [
    "check_id::nn fk=equipment_checks del=cascade:", "description:text:nn:",
    "status:reservation_status:nn def='open':", "lifted_on:date::",
])
t("control_plans", OP, "Inspection/control plans (reception, site quality, HSE).", [
    "process_id::fk=processes:", "name:text:nn:", "kind:control_plan_kind:nn:", "document_id::fk=documents:",
    "is_active:boolean:nn def=true:",
])
t("control_points", OP, "What is checked, how, how often, acceptance criteria.", [
    "plan_id::nn fk=control_plans del=cascade:", "characteristic:text:nn:", "method:text::",
    "frequency:frequency::", "acceptance_criteria:text::", "responsible:text::", "record_ref:text::",
    "sort_order:int:nn def=0:",
])
t("inspections", OP, "An executed inspection (monthly HSE inspection, reception control…).", [
    "number:text::", "control_plan_id::fk=control_plans:", "kind:control_plan_kind:nn:", "site_id::fk=sites:",
    "project_id::fk=projects:", "supplier_id::fk=suppliers:", "inspected_on:date:nn:",
    "inspector_membership_id::fk=org_memberships:", "status:inspection_status:nn def='planned':",
    "score:numeric(5,2)::", "summary:text::",
])
t("inspection_results", OP, "Result per point, with photo evidence via attachments.", [
    "inspection_id::nn fk=inspections del=cascade:", "control_point_id::fk=control_points:",
    "item:text::", "result:point_result:nn:", "observation:text::", "sort_order:int:nn def=0:",
])
t("waste_records", OP, "Waste register.", [
    "site_id::fk=sites:", "waste_type:text:nn:", "is_hazardous:boolean:nn def=false:",
    "quantity:numeric(12,3)::", "unit:text::", "recorded_on:date:nn:", "handler_supplier_id::fk=suppliers:",
    "disposal_route:text::", "manifest_ref:text::",
])
t("consumption_records", OP, "Energy, water, fuel consumption (e.g. monthly fuel per vehicle).", [
    "site_id::fk=sites:", "equipment_id::fk=equipment:", "resource:resource_type:nn:",
    "period_start:date:nn:", "period_end:date:nn:", "quantity:numeric(14,3):nn:", "unit:text:nn:",
    "cost:numeric(12,2)::",
])
t("environmental_measurements", OP, "Noise, emissions, effluents vs limits.", [
    "site_id::fk=sites:", "parameter:text:nn:", "measured_on:date:nn:", "value:numeric(14,4):nn:",
    "unit:text::", "limit_value:numeric(14,4)::", "lab_supplier_id::fk=suppliers:", "is_compliant:boolean::",
])

-- =====================================================================================
-- Development seed: one consulting firm, its internal org, two clients, five users and
-- enough reference data to click through every module. Idempotent only on an empty DB.
--
--   owner@atlas.test        firm owner          (sees every client of the firm)
--   consultant@atlas.test   consultant          (assigned to Alpha only)
--   qse@alpha.test          Alpha QSE manager
--   gerant@alpha.test       Alpha top management
--   qse@beta.test           Beta QSE manager    (Beta gives the firm read-only access)
-- =====================================================================================
BEGIN;

-- ------------------------------------------------------------------ firm & users
INSERT INTO firms (id, name, legal_name, country, city) VALUES
 ('f0000000-0000-4000-8000-000000000001', 'Atlas QSE Conseil', 'Atlas QSE Conseil SARL', 'TN', 'Tunis');

INSERT INTO users (id, email, full_name, locale) VALUES
 ('b0000000-0000-4000-8000-000000000001', 'owner@atlas.test',      'Amira Ben Salah',  'fr'),
 ('b0000000-0000-4000-8000-000000000002', 'consultant@atlas.test', 'Karim Trabelsi',   'fr'),
 ('b0000000-0000-4000-8000-000000000003', 'qse@alpha.test',        'Sonia Mejri',      'fr'),
 ('b0000000-0000-4000-8000-000000000004', 'gerant@alpha.test',     'Hichem Gharbi',    'fr'),
 ('b0000000-0000-4000-8000-000000000005', 'qse@beta.test',         'Nadia Chaabane',   'fr');

INSERT INTO firm_members (id, firm_id, user_id, role, title) VALUES
 ('c0000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'owner', 'Directrice'),
 ('c0000000-0000-4000-8000-000000000002', 'f0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'consultant', 'Consultant QSE senior');

-- ------------------------------------------------------------------ reference: sectors & standards
INSERT INTO sectors (id, firm_id, code, name) VALUES
 ('d0000000-0000-4000-8000-000000000001', NULL, 'AGRO', 'Agro-alimentaire'),
 ('d0000000-0000-4000-8000-000000000002', NULL, 'BTP', 'Bâtiment et travaux publics'),
 ('d0000000-0000-4000-8000-000000000003', NULL, 'IND', 'Industrie manufacturière'),
 ('d0000000-0000-4000-8000-000000000004', NULL, 'SRV', 'Services');

INSERT INTO standards (id, code, title, system) VALUES
 ('e0000000-0000-4000-8000-000000000001', 'ISO9001',  'Systèmes de management de la qualité', 'quality'),
 ('e0000000-0000-4000-8000-000000000002', 'ISO14001', 'Systèmes de management environnemental', 'environment'),
 ('e0000000-0000-4000-8000-000000000003', 'ISO45001', 'Systèmes de management de la santé et sécurité au travail', 'ohs');

INSERT INTO standard_editions (id, standard_id, edition, published_on) VALUES
 ('e1000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', '2015', '2015-09-15'),
 ('e1000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000002', '2015', '2015-09-15'),
 ('e1000000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000000003', '2018', '2018-03-12');

-- Harmonized-structure top-level clauses (titles only), for each edition.
INSERT INTO clauses (edition_id, number, title, sort_order)
SELECT e.id, c.number, c.title, c.sort_order
FROM standard_editions e
CROSS JOIN (VALUES ('4', 'Contexte de l''organisme', 4), ('5', 'Leadership', 5), ('6', 'Planification', 6),
                   ('7', 'Support', 7), ('8', 'Réalisation des activités opérationnelles', 8),
                   ('9', 'Évaluation des performances', 9), ('10', 'Amélioration', 10)) AS c(number, title, sort_order);

-- ------------------------------------------------------------------ organizations
INSERT INTO organizations (id, firm_id, name, legal_name, type, sector_id, city, headcount, firm_access, onboarded_on) VALUES
 ('a0000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001', 'Atlas QSE Conseil (interne)', NULL, 'internal', 'd0000000-0000-4000-8000-000000000004', 'Tunis', 8, 'full', '2024-01-01'),
 ('a0000000-0000-4000-8000-000000000002', 'f0000000-0000-4000-8000-000000000001', 'Alpha Industries', 'Alpha Industries SA', 'client', 'd0000000-0000-4000-8000-000000000003', 'Sfax', 140, 'full', '2025-03-01'),
 ('a0000000-0000-4000-8000-000000000003', 'f0000000-0000-4000-8000-000000000001', 'Beta BTP', 'Beta BTP SARL', 'client', 'd0000000-0000-4000-8000-000000000002', 'Sousse', 85, 'read_only', '2025-06-15');

INSERT INTO consultant_assignments (organization_id, firm_member_id, role, starts_on) VALUES
 ('a0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000002', 'lead', '2025-03-01');

INSERT INTO org_memberships (id, organization_id, user_id, job_title, joined_at) VALUES
 ('a1000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000003', 'Responsable QSE', now()),
 ('a1000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000004', 'Gérant', now()),
 ('a1000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000005', 'Responsable QSE', now());

INSERT INTO membership_roles (organization_id, membership_id, role_id)
SELECT m.organization_id, m.id, r.id
FROM (VALUES ('a1000000-0000-4000-8000-000000000003'::uuid, 'qse_manager'),
             ('a1000000-0000-4000-8000-000000000003'::uuid, 'org_admin'),
             ('a1000000-0000-4000-8000-000000000004'::uuid, 'top_management'),
             ('a1000000-0000-4000-8000-000000000005'::uuid, 'qse_manager'),
             ('a1000000-0000-4000-8000-000000000005'::uuid, 'org_admin')) AS x(membership_id, code)
JOIN org_memberships m ON m.id = x.membership_id
JOIN roles r ON r.code = x.code AND r.firm_id IS NULL AND r.org_id IS NULL;

INSERT INTO subscriptions (organization_id, plan, status, seats, modules, starts_on) VALUES
 ('a0000000-0000-4000-8000-000000000002', 'with_engagement', 'active', 25, '{documents,risks,improvement,audits}', '2025-03-01'),
 ('a0000000-0000-4000-8000-000000000003', 'standalone', 'active', 10, '{documents,improvement}', '2025-06-15');

-- ------------------------------------------------------------------ Alpha: sites, documents, processes
INSERT INTO sites (organization_id, code, name, type, city) VALUES
 ('a0000000-0000-4000-8000-000000000002', 'SFX-HO', 'Siège & usine Sfax', 'head_office', 'Sfax'),
 ('a0000000-0000-4000-8000-000000000002', 'SFX-WH', 'Entrepôt Thyna', 'warehouse', 'Sfax'),
 ('a0000000-0000-4000-8000-000000000003', 'SOU-HO', 'Siège Sousse', 'head_office', 'Sousse');

INSERT INTO document_types (organization_id, code, label, category, default_review_months)
SELECT o.id, t.code, t.label, t.category::doc_category, t.months
FROM organizations o
CROSS JOIN (VALUES ('PLT', 'Politique', 'policy', 36), ('PCS', 'Fiche processus', 'process_sheet', 24),
                   ('PRO', 'Procédure', 'procedure', 24), ('INT', 'Instruction', 'instruction', 24),
                   ('MAN', 'Manuel', 'manual', 36), ('PLN', 'Plan', 'plan', 12), ('LST', 'Liste', 'list', 12),
                   ('ID', 'Imprimé / formulaire', 'form', 24), ('DOC', 'Document externe', 'external', NULL))
     AS t(code, label, category, months)
WHERE o.type = 'client';

INSERT INTO processes (id, organization_id, code, name, type, owner_membership_id, purpose, sort_order) VALUES
 ('a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'PCS-DIR', 'Pilotage et amélioration', 'management', 'a1000000-0000-4000-8000-000000000004', 'Définir la stratégie et piloter le SMI', 1),
 ('a2000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002', 'PCS-QSE', 'Management QSE', 'management', 'a1000000-0000-4000-8000-000000000003', 'Maîtriser le système de management intégré', 2),
 ('a2000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 'PCS-PRD', 'Production', 'operational', NULL, 'Fabriquer des produits conformes', 3),
 ('a2000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000002', 'PCS-ACH', 'Achats', 'support', NULL, 'Garantir des achats conformes', 4);

INSERT INTO interested_parties (organization_id, name, category, nature, influence, interest) VALUES
 ('a0000000-0000-4000-8000-000000000002', 'Clients donneurs d''ordre', 'Clients', 'external', 3, 3),
 ('a0000000-0000-4000-8000-000000000002', 'Personnel', 'Interne', 'internal', 3, 3),
 ('a0000000-0000-4000-8000-000000000002', 'ANPE', 'Autorités', 'external', 3, 2);

INSERT INTO context_issues (organization_id, nature, swot_type, category, title, systems) VALUES
 ('a0000000-0000-4000-8000-000000000002', 'internal', 'weakness', 'Méthodes', 'Procédures de production non formalisées', '{quality}'),
 ('a0000000-0000-4000-8000-000000000002', 'external', 'opportunity', 'Économique', 'Demande export vers l''UE en hausse', '{quality,environment}'),
 ('a0000000-0000-4000-8000-000000000002', 'external', 'threat', 'Légal', 'Durcissement de la réglementation sur les rejets', '{environment}');

INSERT INTO engagements (organization_id, name, status, lead_consultant_id, started_on, target_certification_on) VALUES
 ('a0000000-0000-4000-8000-000000000002', 'Certification ISO 9001 / 14001 / 45001', 'deployment', 'c0000000-0000-4000-8000-000000000002', '2025-03-01', '2026-12-15');

INSERT INTO nonconformities (id, organization_id, number, title, detected_on, source, severity, process_id, detected_by_membership_id, status) VALUES
 ('a3000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'NC-2026-001', 'Étalonnage du pied à coulisse PAC-03 dépassé', '2026-09-02', 'internal_audit', 'minor', 'a2000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000003', 'action_planned'),
 ('a3000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002', 'NC-2026-002', 'Réclamation client : lot non conforme', '2026-09-20', 'customer_complaint', 'major', 'a2000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000003', 'analysis');

INSERT INTO actions (organization_id, number, title, type, source, priority, status, due_on, nonconformity_id) VALUES
 ('a0000000-0000-4000-8000-000000000002', 'AC-2026-001', 'Étalonner PAC-03 et vérifier les mesures depuis la dernière date valide', 'corrective', 'nonconformity', 'high', 'in_progress', '2026-09-30', 'a3000000-0000-4000-8000-000000000001'),
 ('a0000000-0000-4000-8000-000000000002', 'AC-2026-002', 'Mettre en place un planning d''étalonnage', 'preventive', 'nonconformity', 'medium', 'planned', '2026-11-15', 'a3000000-0000-4000-8000-000000000001');

-- Beta has its own register: Alpha users must never see it.
INSERT INTO nonconformities (organization_id, number, title, detected_on, source, severity, status) VALUES
 ('a0000000-0000-4000-8000-000000000003', 'NC-2026-001', 'Garde-corps absent sur échafaudage', '2026-09-10', 'inspection', 'major', 'open');

COMMIT;

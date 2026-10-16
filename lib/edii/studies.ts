/**
 * Which environmental study the ANPE (Agence nationale de protection de l'environnement) expects
 * for an establishment.
 *
 * Décret n° 2005-1991 du 11 juillet 2005: units of its annexe 1 need an étude d'impact sur
 * l'environnement (EIE), catégorie A or B; units of its annexe 2 sign a cahier des charges. Which
 * annex an activity falls in comes from the decree's own lists, not from the EDII category.
 *
 * - A project not started yet files the EIE or the cahier des charges before it opens.
 * - A unit already operating regularises with an étude de dépollution, drawn up on the ANPE's
 *   terms of reference (circulaire n° 27 du 7 novembre 2024 made it a legal route for classified
 *   establishments; check whether that circular is still in force).
 * - When neither annex applies, the promoter makes a demande d'avis to the ANPE.
 *
 * Review times and steps come from the ANPE's published guidance; check them against the decree's
 * articles once its text is in edii/sources.
 */

export type Annexe = "A" | "B" | "CDC" | "none"; // annexe 1 A, annexe 1 B, annexe 2, neither
export type Situation = "projet" | "existant";
export type StudyKind = "eie_a" | "eie_b" | "cahier_des_charges" | "depollution" | "demande_avis";

export interface Study {
  kind: StudyKind;
  title: string;
  delay: string | null; // the ANPE's review time
  steps: string[];
  basis: string;
}

export const STUDIES: Record<StudyKind, Omit<Study, "delay"> & { delay: (sensitive: boolean) => string | null }> = {
  eie_a: {
    kind: "eie_a",
    title: "Étude d'impact sur l'environnement, catégorie A",
    delay: (sensitive) => (sensitive ? "3 mois ouvrables (zone protégée ou sensible)" : "21 jours ouvrables"),
    steps: [
      "Faire réaliser l'étude d'impact par un bureau d'études.",
      "La déposer à l'ANPE, qui rend son avis avant la réalisation du projet.",
    ],
    basis: "Décret n° 2005-1991, annexe 1, catégorie A",
  },
  eie_b: {
    kind: "eie_b",
    title: "Étude d'impact sur l'environnement, catégorie B",
    delay: () => "3 mois ouvrables",
    steps: [
      "Faire réaliser l'étude d'impact par un bureau d'études.",
      "La déposer à l'ANPE, qui rend son avis avant la réalisation du projet.",
    ],
    basis: "Décret n° 2005-1991, annexe 1, catégorie B",
  },
  cahier_des_charges: {
    kind: "cahier_des_charges",
    title: "Cahier des charges",
    delay: () => null,
    steps: [
      "Télécharger le cahier des charges propre à l'activité.",
      "Le remplir, le signer et le déposer à la direction régionale de l'ANPE la plus proche.",
    ],
    basis: "Décret n° 2005-1991, annexe 2 ; arrêté du 8 mars 2006 approuvant les cahiers des charges",
  },
  depollution: {
    kind: "depollution",
    title: "Étude de dépollution",
    delay: () => null,
    steps: [
      "Demander à l'ANPE les termes de référence de l'étude de dépollution.",
      "Faire réaliser l'étude par un bureau d'études et la soumettre à l'approbation de l'ANPE.",
      "Mettre en œuvre le programme de dépollution approuvé (le FODEP peut en financer une partie).",
    ],
    basis: "Termes de référence de l'ANPE ; circulaire n° 27 du 7 novembre 2024 (régularisation des établissements classés)",
  },
  demande_avis: {
    kind: "demande_avis",
    title: "Demande d'avis",
    delay: () => null,
    steps: ["Adresser une demande d'avis à l'ANPE : l'activité ne relève ni de l'étude d'impact ni d'un cahier des charges."],
    basis: "Décret n° 2005-1991 (activité hors annexes 1 et 2)",
  },
};

/** The study one activity calls for. */
export function studyFor(annexe: Annexe, situation: Situation): StudyKind {
  if (annexe === "none") return "demande_avis";
  if (situation === "existant") return "depollution";
  return annexe === "A" ? "eie_a" : annexe === "B" ? "eie_b" : "cahier_des_charges";
}

// Most demanding first: one EIE covers the whole establishment.
const RANK: StudyKind[] = ["eie_b", "eie_a", "depollution", "cahier_des_charges", "demande_avis"];

export interface EstablishmentStudy {
  study: Study | null; // null while an activity's annex is unknown
  perActivity: StudyKind[];
  unknown: number; // activities whose annex is not known yet
}

/**
 * The study for the establishment: the most demanding of its activities. annexes holds one entry
 * per activity, null when not known yet.
 */
export function establishmentStudy(annexes: (Annexe | null)[], situation: Situation, sensitive: boolean): EstablishmentStudy {
  const known = annexes.filter((a): a is Annexe => a !== null);
  const perActivity = known.map((a) => studyFor(a, situation));
  const unknown = annexes.length - known.length;
  if (!perActivity.length || unknown) return { study: null, perActivity, unknown };
  const kind = RANK.find((k) => perActivity.includes(k))!;
  const s = STUDIES[kind];
  return { study: { ...s, delay: s.delay(sensitive) }, perActivity, unknown };
}

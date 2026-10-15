"use client";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useMemo, useState } from "react";
import {
  additionGroup,
  classify,
  type Classe,
  describe,
  inputUnits,
  type Item,
  nomenclature,
  type Outcome,
  type Rubrique,
  rubrique,
  search,
  variants,
} from "@/lib/edii/classify";

const LABEL: Record<string, string> = { "1": "1ère catégorie", "2": "2ème catégorie", "3": "3ème catégorie", NC: "Non classé" };
const SOURCE = Object.fromEntries(nomenclature.sources.map((s) => [s.id, s]));

function ClasseBadge({ classe, big }: { classe: Classe; big?: boolean }) {
  return <span className={`badge edii-c${classe} ${big ? "edii-big" : ""}`}>{LABEL[String(classe)]}</span>;
}

export default function EdiiPage() {
  return (
    <Suspense fallback={<div className="center muted">Chargement…</div>}>
      <Edii />
    </Suspense>
  );
}

function Edii() {
  const params = useSearchParams();
  const router = useRouter();
  const [query, setQuery] = useState(params.get("q") ?? "");
  const [section, setSection] = useState<string | null>(null);
  const selected = rubrique(params.get("code") ?? "");

  const results = useMemo(() => {
    if (query.trim()) return search(query, 60);
    if (section) return nomenclature.rubriques.filter((r) => r.section === section);
    return [];
  }, [query, section]);

  const open = (code: string) => router.replace(`/edii?code=${encodeURIComponent(code)}${query ? `&q=${encodeURIComponent(query)}` : ""}`);

  return (
    <div className="page edii">
      <div className="page-head">
        <div>
          <h1>Classement des établissements dangereux, insalubres ou incommodes</h1>
          <p className="muted">
            Nomenclature de l&apos;arrêté du 15 novembre 2005, consolidée avec les arrêtés du 23 février 2010 et du 24 octobre 2012.{" "}
            {nomenclature.rubriques.length} rubriques.
          </p>
        </div>
        <Link href="/" className="muted small">
          ← QMS
        </Link>
      </div>

      <div className="edii-layout">
        <aside className="card edii-list">
          <input
            autoFocus
            className="edii-search"
            placeholder="Activité, substance ou n° de rubrique…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          {!query.trim() ? (
            <div className="chips edii-sections">
              {Object.entries(nomenclature.sections)
                .filter(([code]) => !code.endsWith("000"))
                .map(([code, title]) => (
                  <button key={code} className={`chip ${section === code ? "on" : ""}`} onClick={() => setSection(section === code ? null : code)}>
                    {code} · {title}
                  </button>
                ))}
            </div>
          ) : null}
          {query.trim() && results.length === 0 ? (
            <p className="muted small">
              Aucune rubrique ne correspond. Une activité qui ne figure dans aucune rubrique de la nomenclature est <b>non classée</b> ;
              essayer d&apos;autres mots (substance, procédé, produit) avant de conclure.
            </p>
          ) : null}
          <ul className="edii-results">
            {results.map((r) => (
              <li key={r.code}>
                <button className={selected?.code === r.code ? "on" : ""} onClick={() => open(r.code)}>
                  <span className="mono">{r.code}</span> {r.title}
                  {r.kind === "definition" ? <span className="tag">définition</span> : null}
                </button>
              </li>
            ))}
          </ul>
        </aside>

        <main>{selected ? <RubriqueView key={selected.code} rub={selected} onOpen={open} /> : <Intro />}</main>
      </div>
    </div>
  );
}

function Intro() {
  return (
    <div className="card">
      <h2>Comment ça marche</h2>
      <ol className="edii-steps">
        <li>Chercher l&apos;activité ou la substance, ou parcourir une section.</li>
        <li>Ouvrir la rubrique, choisir le cas qui s&apos;applique et saisir la capacité ou la quantité.</li>
        <li>Le classement (1ère, 2ème, 3ème catégorie ou non classé) est calculé à partir des seuils du texte.</li>
      </ol>
      <p className="muted small">
        Les seuils ont été lus par OCR sur les textes publiés au JORT puis vérifiés (voir <span className="mono">edii/review.md</span>). Un
        établissement qui exerce plusieurs activités relève de la catégorie la plus élevée de ses rubriques. Outil d&apos;aide : le texte
        officiel fait foi.
      </p>
      <h3>Textes</h3>
      <ul className="small">
        {nomenclature.sources.map((s) => (
          <li key={s.id}>
            {s.title} <span className="muted">({s.jort})</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function RubriqueView({ rub, onOpen }: { rub: Rubrique; onOpen: (code: string) => void }) {
  const cases = variants(rub);
  const [variant, setVariant] = useState<string | undefined>(cases.length === 1 ? cases[0] : undefined);
  const scope = variant === undefined ? rub : { ...rub, items: rub.items.filter((i) => i.path.join(" › ") === variant) };
  const units = inputUnits(scope);
  const [quantity, setQuantity] = useState("");
  const [chosenUnit, setUnit] = useState("");
  const unit = units.includes(chosenUnit) ? chosenUnit : (units[0] ?? "");
  const [picked, setPicked] = useState<Item | null>(null);
  const group = additionGroup(rub.code);

  const value = quantity.trim() === "" ? undefined : Number(quantity.replace(",", ".").replace(/\s/g, ""));
  const needsVariant = cases.length > 1 && variant === undefined;
  const outcome: Outcome | null = needsVariant ? null : classify(rub, { variant, quantity: Number.isFinite(value) ? value : undefined, unit });

  const caseLabel = (v: string) =>
    v ||
    rub.items
      .filter((i) => i.path.length === 0)
      .map((i) => i.criterion || rub.title)
      .join(" / ");

  return (
    <>
      <div className="card">
        <div className="edii-head">
          <h2>
            <span className="mono">{rub.code}</span> {rub.title}
          </h2>
          <span className="muted small">
            {rub.replaces ? `Modifiée par l'arrêté de ${rub.source}` : rub.source === "2005" ? "Arrêté de 2005" : `Ajoutée par l'arrêté de ${rub.source}`}
          </span>
        </div>
        <p className="edii-text">{rub.text}</p>
        {group ? (
          <p className="edii-note small">
            Règle d&apos;addition (art. 2 bis, arrêté du 23 février 2010) : groupe {group}. Si l&apos;établissement détient plusieurs
            substances du groupe, Σ qx/Qx &gt; 1 le classe dans la catégorie supérieure.
          </p>
        ) : null}
        {rub.items.length ? (
          <div className="table-wrap">
            <table className="grid edii-items">
              <thead>
                <tr>
                  <th>Cas</th>
                  <th>Seuil</th>
                  <th>Catégorie</th>
                </tr>
              </thead>
              <tbody>
                {rub.items.map((it, i) => (
                  <tr key={i}>
                    <td>
                      {it.path.length ? <div className="muted small">{it.path.join(" › ")}</div> : null}
                      {it.criterion || rub.title}
                    </td>
                    <td>
                      {describe(it.condition)}
                      {it.condition?.unit_inferred ? <span className="tag" title="Unité déduite des autres lignes">déduite</span> : null}
                    </td>
                    <td>
                      <ClasseBadge classe={it.category} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </div>

      <div className="card">
        <h2>Classer un établissement</h2>
        {rub.kind === "definition" || rub.items.length === 0 ? null : (
          <div className="form">
            {cases.length > 1 ? (
              <div className="field wide">
                <label>Cas</label>
                <select value={variant === undefined ? "" : String(cases.indexOf(variant))} onChange={(e) => (setVariant(e.target.value === "" ? undefined : cases[Number(e.target.value)]), setPicked(null))}>
                  <option value="">Choisir le cas qui s&apos;applique…</option>
                  {cases.map((v, i) => (
                    <option key={i} value={i}>
                      {caseLabel(v)}
                    </option>
                  ))}
                </select>
              </div>
            ) : null}
            {units.length ? (
              <div className="field">
                <label>Quantité ou capacité</label>
                <div className="edii-qty">
                  <input inputMode="decimal" value={quantity} onChange={(e) => (setQuantity(e.target.value), setPicked(null))} placeholder="ex. 1500" />
                  <select value={unit} onChange={(e) => setUnit(e.target.value)} aria-label="Unité">
                    {units.map((u) => (
                      <option key={u}>{u}</option>
                    ))}
                  </select>
                </div>
              </div>
            ) : null}
          </div>
        )}
        <Result outcome={outcome} picked={picked} onPick={setPicked} onOpen={onOpen} needsVariant={needsVariant} />
      </div>
    </>
  );
}

function Result({
  outcome,
  picked,
  onPick,
  onOpen,
  needsVariant,
}: {
  outcome: Outcome | null;
  picked: Item | null;
  onPick: (i: Item) => void;
  onOpen: (code: string) => void;
  needsVariant: boolean;
}) {
  if (needsVariant || !outcome) return <p className="muted">Choisir d&apos;abord le cas qui s&apos;applique.</p>;
  switch (outcome.status) {
    case "classified":
      return (
        <div className="edii-result">
          <ClasseBadge classe={outcome.classe} big />
          <p>{outcome.reason}</p>
          {outcome.items[0] ? <p className="muted small">Source : {sourceOf(outcome.items[0])}</p> : null}
          {outcome.notes.map((n) => (
            <p key={n} className="edii-note small">
              {n}
            </p>
          ))}
        </div>
      );
    case "choose":
      return (
        <div className="edii-result">
          <p>{outcome.reason}</p>
          <ul className="edii-choices">
            {outcome.items.map((it, i) => (
              <li key={i}>
                <button className={picked === it ? "on" : ""} onClick={() => onPick(it)}>
                  <ClasseBadge classe={it.category} /> {it.criterion}
                </button>
              </li>
            ))}
          </ul>
          {outcome.belowAll ? <p className="muted small">Si aucun de ces cas ne s&apos;applique : non classé au titre de cette rubrique.</p> : null}
          {picked ? (
            <div className="edii-picked">
              <ClasseBadge classe={picked.category} big /> <span className="muted small">Source : {sourceOf(picked)}</span>
            </div>
          ) : null}
        </div>
      );
    case "needs_quantity":
      return <p className="muted">{outcome.reason}</p>;
    case "unit_mismatch":
      return <p className="error">{outcome.reason}</p>;
    case "definition":
      return (
        <div className="edii-result">
          <p className="muted">{outcome.reason}</p>
          <div className="chips">
            {outcome.related.map((c) => (
              <button key={c} className="chip" onClick={() => onOpen(c)}>
                {c}
              </button>
            ))}
          </div>
        </div>
      );
  }
}

function sourceOf(it: Item): string {
  const id = it.ref.split(" ")[0];
  const s = SOURCE[id];
  const page = it.ref.match(/p\.(\d+)/)?.[1];
  return s ? `${s.title.split(",")[0]} (${s.jort})${page ? `, page ${page} du PDF` : ""}` : it.ref;
}

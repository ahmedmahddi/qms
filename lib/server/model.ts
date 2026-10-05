/**
 * Runtime view of the data model, from db/generated/model.json (built by db/gen.py).
 * The generic records API and the web app are both driven by it, so a table added to
 * db/model.py is reachable end to end after regenerating and migrating.
 */
import raw from "@/db/generated/model.json";
import type { Meta } from "../types";

/** Columns the server fills in; clients can never write them. */
export const SERVER_COLUMNS = new Set(["id", "organization_id", "created_at", "updated_at", "created_by"]);

/** Never written through the generic API: dedicated flows, secrets, or append-only data. */
const NO_GENERIC_WRITE = new Set([
  "users", "invitations", "files", "activity_log", "notifications", "import_jobs", "export_jobs",
  "readiness_snapshots",
]);
/** Not exposed through the generic API at all. */
export const HIDDEN = new Set(["invitations"]);
const SECRET_COLUMNS = new Set(["invitations.token_hash", "users.auth_subject"]);

const IDENT = /^[a-z_][a-z0-9_]*$/;
const SQL_TYPE = /^[a-z_0-9(),[\]]+$/;

export type Col = {
  name: string;
  type: string;
  nn: boolean;
  fk: string | null;
  uq: boolean;
  pk: boolean;
  default: string | null;
  comment: string;
  baseType: string;
  isArray: boolean;
  requiredOnCreate: boolean;
};

export class Table {
  readonly columns: Map<string, Col>;
  readonly pk: string[];

  constructor(
    readonly name: string,
    readonly domain: string,
    readonly desc: string,
    readonly rls: string | null,
    cols: Col[],
    readonly uniques: string[][],
  ) {
    if (!IDENT.test(name)) throw new Error(`bad table name ${name}`);
    for (const c of cols) {
      if (!IDENT.test(c.name)) throw new Error(`bad column name ${name}.${c.name}`);
      if (!SQL_TYPE.test(c.type)) throw new Error(`bad type ${name}.${c.name}: ${c.type}`);
    }
    this.columns = new Map(cols.map((c) => [c.name, c]));
    this.pk = cols.filter((c) => c.pk).map((c) => c.name);
  }

  get isTenant() {
    const c = this.columns.get("organization_id");
    return !!c && c.nn && c.fk === "organizations";
  }
  get isLink() {
    return !(this.pk.length === 1 && this.pk[0] === "id");
  }
  get writable() {
    return !NO_GENERIC_WRITE.has(this.name);
  }
  readableColumns(): string[] {
    return [...this.columns.keys()].filter((c) => !SECRET_COLUMNS.has(`${this.name}.${c}`));
  }

  /** SQL giving a human label for a row. Built only from model identifiers, never request input. */
  labelSql(a = "t"): string {
    const special: Record<string, string> = {
      org_memberships: `(SELECT u.full_name FROM users u WHERE u.id = ${a}.user_id)`,
      firm_members: `(SELECT u.full_name FROM users u WHERE u.id = ${a}.user_id)`,
      standard_editions: `(SELECT s.code FROM standards s WHERE s.id = ${a}.standard_id) || ':' || ${a}.edition`,
      clauses: `${a}.number || ' ' || ${a}.title`,
      document_versions: `'rev. ' || ${a}.revision`,
    };
    if (special[this.name]) return special[this.name];
    const has = (c: string) => this.columns.has(c);
    for (const [key, rest] of [["code", ["name", "title", "label"]], ["number", ["title", "name"]], ["reference", ["title"]]] as const)
      if (has(key)) for (const r of rest) if (has(r)) return `coalesce(${a}.${key} || ' — ', '') || ${a}.${r}`;
    for (const c of ["name", "title", "label", "full_name", "email", "number", "reference", "requirement", "code", "edition", "activity"])
      if (this.columns.get(c)?.baseType === "text") return `${a}.${c}`;
    return has("id") ? `${a}.id::text` : "''";
  }

  searchColumns(): string[] {
    return ["code", "number", "reference", "name", "title", "label", "full_name", "email", "description", "requirement"]
      .filter((c) => this.columns.get(c)?.type === "text");
  }
}

type RawModel = {
  domains: Record<string, string>;
  enums: Record<string, string[]>;
  stats: Meta["stats"];
  dictionary: {
    name: string; domain: string; desc: string; rls: string | null; uniques: string[][];
    cols: { name: string; type: string; nn: boolean; fk: string | null; uq: boolean; pk: boolean; default: string | null; comment: string | null }[];
  }[];
};

const data = raw as unknown as RawModel;

export const model = {
  domains: data.domains,
  enums: data.enums,
  stats: data.stats,
  tables: new Map(
    data.dictionary.map((t) => {
      const cols: Col[] = t.cols.map((c) => {
        const baseType = c.type.replace(/\[\]$/, "");
        return {
          ...c, comment: c.comment ?? "", baseType, isArray: c.type.endsWith("[]"),
          requiredOnCreate: c.nn && c.default === null && !SERVER_COLUMNS.has(c.name),
        };
      });
      return [t.name, new Table(t.name, t.domain, t.desc, t.rls, cols, t.uniques)];
    }),
  ),
  table(name: string): Table | undefined {
    return HIDDEN.has(name) ? undefined : this.tables.get(name);
  },
};

/** Metadata as served to the web app. */
export function publicMeta(): Meta {
  const tables = [...model.tables.values()].filter((t) => !HIDDEN.has(t.name)).map((t) => {
    const readable = new Set(t.readableColumns());
    return {
      name: t.name, domain: t.domain, desc: t.desc, rls: t.rls, tenant: t.isTenant, link: t.isLink,
      pk: t.pk, writable: t.writable, uniques: t.uniques,
      columns: [...t.columns.values()].filter((c) => readable.has(c.name)).map((c) => ({
        name: c.name, type: c.type, base_type: c.baseType, array: c.isArray, nn: c.nn, fk: c.fk, uq: c.uq,
        pk: c.pk, default: c.default, comment: c.comment, required: c.requiredOnCreate, enum: c.baseType in model.enums,
      })),
    };
  });
  return { domains: model.domains, enums: model.enums, tables, stats: model.stats };
}

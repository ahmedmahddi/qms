// Shapes shared by the API and the web app.

export type Column = {
  name: string;
  type: string;
  base_type: string;
  array: boolean;
  nn: boolean;
  fk: string | null;
  uq: boolean;
  pk: boolean;
  default: string | null;
  comment: string;
  required: boolean;
  enum: boolean;
};

export type TableMeta = {
  name: string;
  domain: string;
  desc: string;
  rls: string | null;
  tenant: boolean;
  link: boolean;
  pk: string[];
  writable: boolean;
  uniques: string[][];
  columns: Column[];
};

export type Meta = {
  domains: Record<string, string>;
  enums: Record<string, string[]>;
  tables: TableMeta[];
  stats: { tables: number; enums: number; fks: number; columns: number };
};

export type Org = {
  id: string;
  name: string;
  type: "client" | "internal" | "prospect";
  firm_id: string;
  firm_name: string;
  firm_access: "full" | "read_only" | "none";
  status: string;
  is_member: boolean;
  is_firm_side: boolean;
  can_write: boolean;
  permissions: string[];
};

export type Me = {
  user: { id: string; email: string; full_name: string; locale: string; is_platform_admin: boolean };
  firms: { id: string; name: string; role: string; title: string | null }[];
  organizations: Org[];
};

export type Row = Record<string, unknown> & { id?: string; _label?: string };

export type Page = { items: Row[]; total: number; limit: number; offset: number };

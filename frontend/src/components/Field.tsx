import { isLongText } from "../labels";
import { useMeta } from "../session";
import type { Column } from "../types";
import { useOptions } from "./lookups";

type Props = {
  col: Column;
  value: unknown;
  orgId: string;
  disabled?: boolean;
  onChange: (v: unknown) => void;
};

/** One form control per column type, so every table in the model gets a usable form. */
export function Field({ col, value, orgId, disabled, onChange }: Props) {
  const { data: meta } = useMeta();
  const id = `f-${col.name}`;

  if (col.fk) return <FkSelect col={col} value={value} orgId={orgId} disabled={disabled} onChange={onChange} />;

  if (col.enum && col.array) {
    const options = meta?.enums[col.base_type] ?? [];
    const selected = new Set((value as string[] | null) ?? []);
    return (
      <div className="chips">
        {options.map((o) => (
          <label key={o} className={`chip ${selected.has(o) ? "on" : ""}`}>
            <input
              type="checkbox"
              disabled={disabled}
              checked={selected.has(o)}
              onChange={(e) => {
                const next = new Set(selected);
                if (e.target.checked) next.add(o);
                else next.delete(o);
                onChange(options.filter((x) => next.has(x)));
              }}
            />
            {o.replace(/_/g, " ")}
          </label>
        ))}
      </div>
    );
  }

  if (col.enum) {
    const options = meta?.enums[col.base_type] ?? [];
    return (
      <select id={id} disabled={disabled} value={(value as string) ?? ""} onChange={(e) => onChange(e.target.value || null)}>
        {!col.nn || value == null ? <option value="">—</option> : null}
        {options.map((o) => (
          <option key={o} value={o}>
            {o.replace(/_/g, " ")}
          </option>
        ))}
      </select>
    );
  }

  switch (col.base_type) {
    case "boolean":
      return (
        <input
          id={id}
          type="checkbox"
          disabled={disabled}
          checked={value === true}
          onChange={(e) => onChange(e.target.checked)}
        />
      );
    case "date":
      return (
        <input id={id} type="date" disabled={disabled} value={(value as string) ?? ""} onChange={(e) => onChange(e.target.value || null)} />
      );
    case "timestamptz":
      return (
        <input
          id={id}
          type="datetime-local"
          disabled={disabled}
          value={value ? toLocalInput(String(value)) : ""}
          onChange={(e) => onChange(e.target.value ? new Date(e.target.value).toISOString() : null)}
        />
      );
    case "int":
    case "bigint":
      return <NumberInput id={id} step="1" value={value} disabled={disabled} onChange={onChange} />;
    case "jsonb":
      return (
        <textarea
          id={id}
          className="mono"
          rows={5}
          disabled={disabled}
          value={typeof value === "string" ? value : value == null ? "" : JSON.stringify(value, null, 2)}
          onChange={(e) => onChange(e.target.value)}
        />
      );
  }
  if (col.base_type.startsWith("numeric")) {
    return <NumberInput id={id} step="any" value={value} disabled={disabled} onChange={onChange} />;
  }
  if (col.array) {
    return (
      <input
        id={id}
        disabled={disabled}
        placeholder="comma, separated"
        value={((value as string[] | null) ?? []).join(", ")}
        onChange={(e) => onChange(e.target.value.split(",").map((s) => s.trim()).filter(Boolean))}
      />
    );
  }
  if (isLongText(col)) {
    return <textarea id={id} rows={3} disabled={disabled} value={(value as string) ?? ""} onChange={(e) => onChange(e.target.value || null)} />;
  }
  return <input id={id} disabled={disabled} value={(value as string) ?? ""} onChange={(e) => onChange(e.target.value || null)} />;
}

function NumberInput(props: { id: string; step: string; value: unknown; disabled?: boolean; onChange: (v: unknown) => void }) {
  return (
    <input
      id={props.id}
      type="number"
      step={props.step}
      disabled={props.disabled}
      value={props.value == null ? "" : String(props.value)}
      onChange={(e) => props.onChange(e.target.value === "" ? null : e.target.value)}
    />
  );
}

function FkSelect({ col, value, orgId, disabled, onChange }: Props) {
  const { data, isLoading } = useOptions(col.fk, orgId);
  const current = value == null ? "" : String(value);
  const known = data?.some((o) => o.id === current);
  return (
    <select id={`f-${col.name}`} disabled={disabled || isLoading} value={current} onChange={(e) => onChange(e.target.value || null)}>
      <option value="">{isLoading ? "Loading…" : "—"}</option>
      {current && !known && !isLoading ? <option value={current}>{current.slice(0, 8)}… (not visible)</option> : null}
      {data?.map((o) => (
        <option key={o.id} value={o.id}>
          {o.label}
        </option>
      ))}
    </select>
  );
}

function toLocalInput(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

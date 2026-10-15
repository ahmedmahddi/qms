// EDII classification. Expected categories are read off the scanned official texts.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { additionGroup, classify, type Input, rubrique, search, variants } from "@/lib/edii/classify";

function classe(code: string, input: Input = {}) {
  const rub = rubrique(code);
  if (!rub) throw new Error(`no rubrique ${code}`);
  const out = classify(rub, input);
  return out.status === "classified" ? out.classe : out.status;
}

describe("thresholds", () => {
  it("1101 bovins: veaux de boucherie", () => {
    const veaux = variants(rubrique("1101")!).find((v) => v.startsWith("1) veaux"))!;
    expect(classe("1101", { quantity: 250, unit: "animaux", variant: veaux })).toBe(1);
    expect(classe("1101", { quantity: 200, unit: "animaux", variant: veaux })).toBe(2); // "de plus de 200" excludes 200
    expect(classe("1101", { quantity: 30, unit: "animaux", variant: veaux })).toBe(3);
    expect(classe("1101", { quantity: 5, unit: "animaux", variant: veaux })).toBe("NC");
  });

  it("1101 bovins: vaches laitières", () => {
    const vaches = variants(rubrique("1101")!).find((v) => v.startsWith("2) vaches"))!;
    expect(classe("1101", { quantity: 81, unit: "vaches", variant: vaches })).toBe(1);
    expect(classe("1101", { quantity: 50, unit: "vaches", variant: vaches })).toBe(2);
  });

  it("2502 acétylène, with unit conversion", () => {
    expect(classe("2502", { quantity: 60, unit: "t" })).toBe(1);
    expect(classe("2502", { quantity: 5000, unit: "kg" })).toBe(2);
    expect(classe("2502", { quantity: 1, unit: "t" })).toBe(2); // "supérieure ou égale à 1 t"
    expect(classe("2502", { quantity: 500, unit: "kg" })).toBe(3);
    expect(classe("2502", { quantity: 50, unit: "kg" })).toBe("NC");
    expect(classe("2502", { quantity: 5, unit: "m3" })).toBe("unit_mismatch");
  });

  it("1214 lait, thresholds in litres", () => {
    expect(classe("1214", { quantity: 40000, unit: "l" })).toBe(2);
    expect(classe("1214", { quantity: 30, unit: "m3" })).toBe(3); // "≤ 30 000 l"
    expect(classe("1214", { quantity: 500, unit: "l" })).toBe("NC");
  });

  it("asks for a quantity when the category depends on one", () => {
    expect(classe("2502")).toBe("needs_quantity");
  });

  it("classifies without a quantity when the rubrique has no threshold", () => {
    expect(classe("1401")).toBe(1); // accumulateurs et piles
  });
});

describe("amendments", () => {
  it("2105 is the 2010 version (10 t), not the 2005 one (50 t)", () => {
    const rub = rubrique("2105")!;
    expect(rub.source).toBe("2010");
    expect(rub.replaces).toBe("2005");
    expect(classe("2105", { quantity: 10, unit: "t" })).toBe(1);
    expect(classe("2105", { quantity: 9, unit: "t" })).toBe(2);
  });

  it("2505 gaz inflammables liquéfiés is the 2012 version", () => {
    const rub = rubrique("2505")!;
    expect(rub.source).toBe("2012");
    const vrac = variants(rub).find((v) => v.includes("réservoirs fixes"))!;
    expect(classe("2505", { quantity: 150, unit: "m3", variant: vrac })).toBe(1);
    expect(classe("2505", { quantity: 10, unit: "m3", variant: vrac })).toBe(2);
  });

  it("new rubriques from 2010 and 2012 are in force", () => {
    expect(rubrique("1419 bis 2")?.source).toBe("2010");
    expect(classe("1426")).toBe(1); // hydrocarbures, quelle que soit la capacité (2012)
  });

  it("a definition points to its sub-rubriques", () => {
    const out = classify(rubrique("2722")!);
    expect(out.status).toBe("definition");
    expect(out.status === "definition" && out.related).toEqual(["2722 bis 1", "2722 bis 2"]);
  });
});

describe("search and rules", () => {
  it("finds by code and by words, ignoring accents", () => {
    expect(search("2722 bis").map((r) => r.code)).toEqual(["2722 bis 1", "2722 bis 2"]);
    expect(search("peroxydes organiques").map((r) => r.code)).toContain("2104");
    expect(search("elevage bovins").map((r) => r.code)[0]).toBe("1101");
  });

  it("knows the addition-rule groups of art. 2 bis", () => {
    expect(additionGroup("2725")).toBe(1);
    expect(additionGroup("2715")).toBe(2);
    expect(additionGroup("2505")).toBe(3);
    expect(additionGroup("2506")).toBeNull();
  });
});

it("edii/nomenclature.json matches the OCR output and corrections", () => {
  const file = path.join(__dirname, "..", "edii", "nomenclature.json");
  const before = readFileSync(file, "utf8");
  try {
    execFileSync("python3", ["-I", path.join(__dirname, "..", "edii", "pipeline", "parse.py")], { stdio: "pipe" });
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === "ENOENT") return; // no python: CI runs this check
    throw e;
  }
  expect(readFileSync(file, "utf8"), "edii/nomenclature.json is stale: run `npm run edii:parse` and commit").toBe(before);
});

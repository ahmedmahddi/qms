# EDII: classification of dangerous, unhealthy or noxious establishments

Tunisian law (code du travail, art. 294) classes *établissements dangereux, insalubres ou
incommodes* in a **1ère**, **2ème** or **3ème catégorie** according to a nomenclature of activities
and substances. An establishment whose activity is in no rubrique, or below the smallest threshold
of its rubrique, is **non classé**.

This folder turns the official texts into data, and `lib/edii/classify.ts` classifies an
establishment from that data. No AI is involved: the categories come from the tables of the texts,
read by OCR, then checked.

## Texts

| File | Text | Role |
|---|---|---|
| `sources/2005-11-15-arrete-nomenclature.pdf` | Arrêté du 15 novembre 2005 (JORT n° 94) | The nomenclature (24 scanned pages) |
| `sources/2010-02-23-arrete-modificatif.pdf` | Arrêté du 23 février 2010 (JORT n° 18) | Annex 1 replaces rubriques, annex 2 adds rubriques, art. 2 bis adds the addition rule |
| `sources/2012-10-24-arrete-modificatif.pdf` | Arrêté du 24 octobre 2012 (JORT n° 88) | Same structure: annex 1 replaces, annex 2 adds |
| `sources/2006-10-09-decret-2006-2687.pdf` | Décret n° 2006-2687 du 9 octobre 2006 | Procedures per category (reference only, not parsed) |

`sources.json` says which pages hold the tables and what each annex does.

## Pipeline

```bash
npm run edii:ocr     # stage 1: scans → edii/ocr/<source>.json  (needs tesseract + fra, pdftoppm, numpy, Pillow)
npm run edii:parse   # stage 2: OCR + corrections → nomenclature.json and review.md  (Python standard library only)
```

**Stage 1, `pipeline/ocr.py`.** OCR on a whole page mixes up the three columns (N° | Désignation | CAT).
For each page, the script:

1. renders the page at 300 dpi and straightens it, using the table's vertical rules,
2. finds the four vertical rules,
3. erases the dotted leaders (`animaux ........ 2`), which would otherwise swallow the unit
   (`10 t......` came out as `10 ts`),
4. OCRs the code column and the designation column separately,
5. finds each digit in the CAT column as a blob of ink, then reads it as a single character.
   Reading the whole column at once missed digits that touch a rule.

The output keeps every line with its position and confidence, so stage 2 can change without
running the OCR again. It is committed, so the OCR only runs again when a source changes.

**Stage 2, `pipeline/parse.py`.** It matches codes and categories to lines by position, and
cleans up recurring misreads (`1/j` → `l/j`, `m°` → `m3`, `It` → `1 t`…). It rebuilds each
rubrique's cases (`1)`, `a)`, `I)`) and parses each threshold into a numeric range in a canonical
unit (`supérieure à 2 t, mais inférieure à 75 t` → `2000 < x < 75000 kg`). Then it applies the
amendments in order. It writes:

* `nomenclature.json`: the consolidated rubriques in force, read by the app.
* `review.md`: what a person still has to check against the scans.

`review.md` lists low-confidence category digits, thresholds without a readable unit, and ranges
that overlap or go the wrong way (a larger quantity giving a less severe category). It also lists
odd digit grouping in the official text (`6 5000 kg` in the 2012 text) and corrections that no
longer match anything.

## Fixing a misread

Check the point against the scan (the reference is `source p.<PDF page> y=<pixel row>` at
300 dpi), then add an entry to `corrections.json`:

* `text`: replace `find` with `replace` in the lines of one source page,
* `category`: set the category of the line that starts with `line_starts`. This entry also
  confirms a low-confidence digit that is correct.

Run `npm run edii:parse` and commit the result. `tests/edii.test.ts` fails when
`nomenclature.json` no longer matches what the parser produces.

## Classifying

The page at `/edii` classifies a whole establishment. Search each activity or substance, add it
with "+", then choose its case and enter its quantity. The list is kept in the URL, so a
classification can be bookmarked or shared.

`lib/edii/classify.ts` classifies one rubrique:

* `search(query)`: rubriques by code (`2722 bis`) or words, ignoring accents.
* `classify(rubrique, { variant, quantity, unit })`: returns one of these outcomes:
  * `classified`: category 1, 2 or 3, or `NC` (non classé) below the smallest threshold.
  * `choose`: several cases of the rubrique may apply, and the text decides between them, not a number.
  * `needs_quantity`: the category depends on a threshold.
  * `unit_mismatch`: the quantity is in a unit the rubrique does not use.
  * `definition`: the rubrique only defines a family of substances and points to its sub-rubriques.

Units convert to the canonical unit of each threshold: t ↔ kg, l ↔ m3, kg/j ↔ t/j, MW ↔ kW, ha ↔ m2, MBq ↔ GBq.
When a condition can't be reduced to one number (two thresholds at once, or no unit), the
classifier shows the text instead of guessing.

`lib/edii/establishment.ts` combines the activities:

* **Several activities.** The establishment takes the most severe category of its activities.
  Décret n° 2006-2687, art. 5: an establishment with several classified activities makes a single
  request, has a single public enquiry and gets a single authorisation.
* **Règle d'addition** (arrêté du 23 février 2010, art. 2 bis). When the establishment stores or
  uses two or more substances of the same group, it computes Σ qx/Qx. If the sum is above 1, the
  establishment is classed in *la catégorie supérieure qui suit*.
  * qx is the quantity held.
  * Qx is the threshold of the category just above the group's current one (the most severe
    category of its substances taken one by one, or 3ème when they are all non classé). At their
    own category, each classified substance alone would already reach 1, so the rule would always apply.
  * The groups are:
    * Groupe 1: 2703, 2704, 2706, 2708, 2722 bis 1, 2722 bis 2, 2723, 2724 bis 1, 2724 bis 2, 2725, 2726.
    * Groupe 2: 2711, 2712, 2713, 2715, 2720.
    * Groupe 3: the 2100 rubriques, 2402 to 2408, and the 2500 rubriques except 2503, 2506, 2507 bis, 2514, 2516.
  * Example: acétylène 30 t (2502) and hydrogène 30 t (2509) are each 2ème catégorie. With the 1ère
    thresholds (50 t each), 30/50 + 30/50 = 1.2 > 1, so the establishment is classed 1ère catégorie.

## Not done yet

* **Reading of the addition rule**: the text does not say which threshold Qx is. The reading
  above (the category just above) is the only one under which the rule can ever leave a category
  unchanged; it should be confirmed.
* **Reading of 2724**: the 2010 text restates rubrique 2724 as a definition only, in its "complete"
  annex, and moves the thresholds to 2724 bis 1 and bis 2. The parser treats the restatement as a
  replacement. This reading should be confirmed (see `review.md`).

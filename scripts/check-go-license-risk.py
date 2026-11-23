#!/usr/bin/env python3
"""Classify go-licenses CSV output and emit a GitHub Actions risk report."""

import csv
import os
import re
import sys
from pathlib import Path

SOURCE = Path(sys.argv[1] if len(sys.argv) > 1 else "go-dependency-licenses/GO_DEPENDENCY_LICENSES.csv")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "go-dependency-licenses/GO_LICENSE_RISK_REPORT.md")

# Conservative allow-list of common permissive licenses and recognized weak-copyleft licenses.
PERMISSIVE = {
    "MIT", "ISC", "BSD-2-CLAUSE", "BSD-3-CLAUSE", "BSD-2-CLAUSE-PATENT",
    "BSD-3-CLAUSE-ATTRIBUTION", "APACHE-2.0", "ZLIB", "0BSD",
    "CC0-1.0", "UNLICENSE", "BSL-1.0", "ARTISTIC-2.0",
}
WEAK_COPYLEFT = {"MPL-2.0", "LGPL-2.0", "LGPL-2.1", "LGPL-3.0", "EPL-1.0", "EPL-2.0", "CDDL-1.0", "CDDL-1.1"}
ALIASES = {
    "APACHE LICENSE 2.0": "APACHE-2.0",
    "BSD 2-CLAUSE": "BSD-2-CLAUSE",
    "BSD 3-CLAUSE": "BSD-3-CLAUSE",
    "BSD 2-CLAUSE LICENSE": "BSD-2-CLAUSE",
    "BSD 3-CLAUSE LICENSE": "BSD-3-CLAUSE",
    "GNU GENERAL PUBLIC LICENSE": "GPL",
    "GNU AFFERO GENERAL PUBLIC LICENSE": "AGPL",
    "GNU LESSER GENERAL PUBLIC LICENSE": "LGPL",
}

def norm(value):
    value = re.sub(r"\s+", " ", (value or "").strip()).upper()
    return ALIASES.get(value, value)

def classify(value):
    v = norm(value)
    if not v or v in {"UNKNOWN", "UNLICENSED", "NOASSERTION", "NONE", "N/A"} or "UNKNOWN" in v:
        return "UNKNOWN", "Unknown or unrecognized license; manual identification required"
    if "AGPL" in v or "AFFERO" in v:
        return "HIGH", "AGPL network copyleft; legal review required before distribution/service use"
    if "GPL" in v or "GNU GENERAL PUBLIC LICENSE" in v:
        return "HIGH", "GPL copyleft; review linking, distribution and source-offer obligations"
    if any(x in v for x in ("SSPL", "BUSL", "COMMONS CLAUSE", "PROPRIETARY", "NONCOMMERCIAL")):
        return "HIGH", "Source-available or restricted license; compatibility review required"
    if any(x in v for x in ("LGPL", "MPL", "EPL", "CDDL")):
        return "REVIEW", "Weak-copyleft license; review file/module and distribution obligations"
    if v in PERMISSIVE:
        return "OK", "Common permissive license"
    # Expressions and compound license declarations need a human review, even if they
    # contain a permissive identifier: do not silently approve an unfamiliar expression.
    if " OR " in v or " AND " in v or "/" in v or ";" in v:
        return "REVIEW", "Compound license expression; confirm applicable licensing option"
    return "UNKNOWN", "License identifier is not on the reviewed allow-list"

def main():
    if not SOURCE.is_file() or SOURCE.stat().st_size == 0:
        raise SystemExit(f"ERROR: license CSV missing or empty: {SOURCE}")
    with SOURCE.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise SystemExit("ERROR: license CSV has no header")
        license_col = next((h for h in reader.fieldnames if "license" in h.lower() and "url" not in h.lower()), None)
        package_col = next((h for h in reader.fieldnames if h.lower() in {"package", "module", "dependency"}), None)
        if not license_col:
            raise SystemExit("ERROR: cannot identify license column; expected a header containing 'license'")
        rows = list(reader)

    results = []
    for row in rows:
        raw = (row.get(license_col) or "").strip()
        package = (row.get(package_col) or " (package not provided)").strip() if package_col else "(package not provided)"
        level, reason = classify(raw)
        results.append((level, package, raw or "(empty)", reason))

    high = [x for x in results if x[0] == "HIGH"]
    review = [x for x in results if x[0] == "REVIEW"]
    unknown = [x for x in results if x[0] == "UNKNOWN"]
    ok = [x for x in results if x[0] == "OK"]

    lines = [
        "# Go dependency license risk report", "",
        f"- Dependencies scanned: **{len(results)}**",
        f"- Permissive / recognized: **{len(ok)}**",
        f"- Copyleft / manual review: **{len(high) + len(review)}** (GPL/AGPL or restricted: {len(high)}; weak/compound: {len(review)})",
        f"- Unknown / unrecognized: **{len(unknown)}**", "",
        "> This is an automated triage report, not legal advice. A dependency license is not automatically incompatible; assess how it is used and distributed.", "",
    ]
    if high or review or unknown:
        lines += ["## Items requiring attention", "", "| Risk | Package/module | License | Finding |", "|---|---|---|---|"]
        for level, package, license_name, reason in high + review + unknown:
            lines.append(f"| {level} | {package.replace('|', '/')} | {license_name.replace('|', '/')} | {reason} |")
    else:
        lines += ["No license risks were detected by the current allow-list."]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    for level, package, license_name, reason in high + review:
        command = "warning"
        print(f"::{command} title=Go license risk::{package}: {license_name} — {reason}")
    for level, package, license_name, reason in unknown:
        print(f"::error title=Unknown Go dependency license::{package}: {license_name} — {reason}")

    print(f"License risk scan: total={len(results)}, high={len(high)}, review={len(review)}, unknown={len(unknown)}, ok={len(ok)}")
    # Unknown licenses are fail-closed. Known GPL/AGPL and weak-copyleft licenses
    # generate visible warnings and a Release report, leaving compatibility decisions explicit.
    if unknown:
        raise SystemExit(2)

if __name__ == "__main__":
    main()

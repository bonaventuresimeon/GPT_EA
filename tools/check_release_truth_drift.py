#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path
from json_bundle import materialize_legacy_json_documents

materialize_legacy_json_documents()

ROOT = Path(__file__).resolve().parents[1]
OUT_DEFAULT = ROOT / "release-truth-drift-validation.txt"

MARKERS = {
    "schema": re.compile(r"^<!-- RELEASE_TRUTH_SCHEMA: (.+) -->$", re.M),
    "evidence_sha256": re.compile(r"^<!-- RELEASE_TRUTH_EVIDENCE_SHA256: ([0-9a-f]{64}) -->$", re.M),
    "fingerprint": re.compile(r"^<!-- RELEASE_TRUTH_FINGERPRINT: ([0-9a-f]{64}) -->$", re.M),
    "overall": re.compile(r"^<!-- RELEASE_TRUTH_OVERALL: (.+) -->$", re.M),
}


def load_generator():
    path = ROOT / "tools" / "generate_release_truth_dashboard.py"
    spec = importlib.util.spec_from_file_location("gpt_ea_release_truth", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load release-truth generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    ap = argparse.ArgumentParser(description="Detect drift between release evidence and a generated GPT_EA release-truth dashboard.")
    ap.add_argument("evidence", nargs="?", default="RELEASE_EVIDENCE_TEMPLATE.json")
    ap.add_argument("--dashboard", default="docs/RELEASE_TRUTH_DASHBOARD.md")
    ap.add_argument("--output", default=str(OUT_DEFAULT))
    args = ap.parse_args()

    evidence = Path(args.evidence)
    dashboard = Path(args.dashboard)
    output = Path(args.output)
    if not evidence.is_absolute():
        evidence = ROOT / evidence
    if not dashboard.is_absolute():
        dashboard = ROOT / dashboard
    if not output.is_absolute():
        output = ROOT / output

    errors: list[str] = []
    if not evidence.exists():
        errors.append(f"evidence file not found: {evidence}")
    if not dashboard.exists():
        errors.append(f"dashboard file not found: {dashboard}")

    if errors:
        text = "RELEASE TRUTH DRIFT: FAILED\n" + "\n".join("ERROR: " + e for e in errors) + "\n"
        output.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    try:
        data = json.loads(evidence.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"invalid evidence JSON: {exc}")
        data = {}

    dashboard_text = dashboard.read_text(encoding="utf-8")
    found: dict[str, str] = {}
    for key, pattern in MARKERS.items():
        match = pattern.search(dashboard_text)
        if match is None:
            errors.append(f"dashboard missing deterministic marker: {key}")
        else:
            found[key] = match.group(1).strip()

    if not errors:
        try:
            gen = load_generator()
            expected_schema = gen.TRUTH_SCHEMA
            expected_evidence_sha = gen.canonical_evidence_sha256(data)
            expected_fingerprint = gen.semantic_truth_fingerprint(data)
            _, expected_overall, _ = gen.assess(data)

            expected = {
                "schema": expected_schema,
                "evidence_sha256": expected_evidence_sha,
                "fingerprint": expected_fingerprint,
                "overall": expected_overall,
            }
            for key, value in expected.items():
                if found.get(key) != value:
                    errors.append(f"{key} drift: dashboard={found.get(key)!r} expected={value!r}")
        except Exception as exc:
            errors.append(f"could not recompute release truth: {exc}")

    if errors:
        text = "RELEASE TRUTH DRIFT: FAILED\n" + "\n".join("ERROR: " + e for e in errors) + "\n"
        output.write_text(text, encoding="utf-8")
        print(text, end="")
        return 1

    text = (
        "RELEASE TRUTH DRIFT: PASS\n"
        f"EVIDENCE={evidence}\n"
        f"DASHBOARD={dashboard}\n"
        f"EVIDENCE_SHA256={found['evidence_sha256']}\n"
        f"TRUTH_FINGERPRINT={found['fingerprint']}\n"
        f"OVERALL={found['overall']}\n"
    )
    output.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

ALLOWED_STATUSES = {"Proposed", "Accepted", "Superseded", "Rejected", "Deprecated"}
ADR_FILE_RE = re.compile(r"^ADR_(\d{3})_.+\.md$")
HEADING_RE = re.compile(r"^# ADR-(\d{3}): (.+)$", re.M)


def meta(text: str, key: str) -> str:
    m = re.search(rf"^\*\*{re.escape(key)}:\*\*\s*(.+?)(?:\s{{2}})?$", text, re.M)
    return m.group(1).strip() if m else ""


def refs(value: str) -> list[str]:
    value = value.strip()
    if not value or value in {"None", "—", "-"}:
        return []
    return [x.strip() for x in value.split(",") if x.strip()]


adr_paths = sorted(
    p for p in ROOT.glob("ADR_[0-9][0-9][0-9]_*.md")
    if p.name != "ADR_TEMPLATE.md"
)

records: dict[str, dict[str, object]] = {}
for p in adr_paths:
    fm = ADR_FILE_RE.match(p.name)
    if fm is None:
        errors.append(f"invalid ADR filename: {p.name}")
        continue

    text = p.read_text(encoding="utf-8")
    hm = HEADING_RE.search(text)
    if hm is None:
        errors.append(f"{p.name}: missing ADR heading")
        continue

    file_num = fm.group(1)
    heading_num = hm.group(1)
    adr_id = meta(text, "ADR ID")
    status = meta(text, "Status")
    supersedes = refs(meta(text, "Supersedes"))
    superseded_by = refs(meta(text, "Superseded by"))

    if file_num != heading_num:
        errors.append(f"{p.name}: filename/heading ADR number mismatch")
    expected_id = f"ADR-{file_num}"
    if adr_id != expected_id:
        errors.append(f"{p.name}: ADR ID must be {expected_id}")
    if expected_id in records:
        errors.append(f"duplicate ADR ID: {expected_id}")
    if status not in ALLOWED_STATUSES:
        errors.append(f"{p.name}: invalid status {status!r}")

    for heading in (
        "## 🎯 Context",
        "## ✅ Decision",
        "## 🧠 Rationale",
        "## ⚖️ Consequences",
        "## 🔀 Alternatives considered",
        "## 🔗 Implementation / evidence hooks",
        "## 🔄 Supersession rule",
    ):
        if heading not in text:
            errors.append(f"{p.name}: missing ADR section {heading}")

    if expected_id in supersedes or expected_id in superseded_by:
        errors.append(f"{p.name}: ADR cannot supersede itself")

    if status == "Superseded" and not superseded_by:
        errors.append(f"{p.name}: Superseded ADR must name at least one replacement")
    if status == "Accepted" and superseded_by:
        errors.append(f"{p.name}: Accepted ADR cannot already have Superseded by metadata")
    if status in {"Rejected", "Proposed"} and superseded_by:
        errors.append(f"{p.name}: {status} ADR should not be marked superseded_by")

    records[expected_id] = {
        "id": expected_id,
        "file": p.name,
        "title": hm.group(2).strip(),
        "status": status,
        "supersedes": supersedes,
        "superseded_by": superseded_by,
    }

# Registry must exactly describe the ADR set.
registry_path = ROOT / "ADR_REGISTRY.json"
if not registry_path.exists():
    errors.append("ADR_REGISTRY.json missing")
    registry_records: dict[str, dict[str, object]] = {}
else:
    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
        if registry.get("schema_version") != "gpt_ea_adr_registry_v1":
            errors.append("ADR_REGISTRY.json schema_version mismatch")
        if registry.get("policy") != "ADR_SUPERSESSION_POLICY.md":
            errors.append("ADR_REGISTRY.json policy reference mismatch")
        registry_records = {}
        for item in registry.get("records", []):
            rid = str(item.get("id", ""))
            if rid in registry_records:
                errors.append(f"ADR_REGISTRY.json duplicate ID: {rid}")
            registry_records[rid] = item
        if set(registry_records) != set(records):
            missing = sorted(set(records) - set(registry_records))
            extra = sorted(set(registry_records) - set(records))
            if missing:
                errors.append("ADR_REGISTRY.json missing IDs: " + ", ".join(missing))
            if extra:
                errors.append("ADR_REGISTRY.json has unknown IDs: " + ", ".join(extra))
        for rid, record in records.items():
            item = registry_records.get(rid)
            if not item:
                continue
            for key in ("file", "title", "status"):
                if str(item.get(key, "")) != str(record.get(key, "")):
                    errors.append(f"{rid}: registry {key} mismatch")
            for key in ("supersedes", "superseded_by"):
                a = sorted(str(x) for x in item.get(key, []))
                b = sorted(str(x) for x in record.get(key, []))
                if a != b:
                    errors.append(f"{rid}: registry {key} mismatch")
    except Exception as exc:
        errors.append(f"ADR_REGISTRY.json invalid: {exc}")
        registry_records = {}

# Supersession cross-links and status semantics.
for rid, record in records.items():
    for old in record["supersedes"]:
        if old not in records:
            errors.append(f"{rid}: supersedes missing ADR {old}")
            continue
        if rid not in records[old]["superseded_by"]:
            errors.append(f"{rid} -> {old}: missing reciprocal Superseded by link")
        if records[old]["status"] != "Superseded":
            errors.append(f"{rid}: superseded ADR {old} must have Status=Superseded")
        if record["status"] != "Accepted":
            errors.append(f"{rid}: replacement ADR that supersedes another decision must be Accepted")

    for new in record["superseded_by"]:
        if new not in records:
            errors.append(f"{rid}: Superseded by references missing ADR {new}")
            continue
        if rid not in records[new]["supersedes"]:
            errors.append(f"{rid} -> {new}: replacement ADR missing reciprocal Supersedes link")

# Detect cycles in old -> replacement graph.
graph = {rid: list(record["superseded_by"]) for rid, record in records.items()}
visiting: set[str] = set()
visited: set[str] = set()


def visit(node: str, trail: list[str]) -> None:
    if node in visiting:
        errors.append("ADR supersession cycle: " + " -> ".join(trail + [node]))
        return
    if node in visited:
        return
    visiting.add(node)
    for nxt in graph.get(node, []):
        if nxt in graph:
            visit(nxt, trail + [node])
    visiting.remove(node)
    visited.add(node)


for rid in sorted(graph):
    visit(rid, [])

# Index and policy/template references.
index = ROOT / "ADR_INDEX.md"
if not index.exists():
    errors.append("ADR_INDEX.md missing")
else:
    text = index.read_text(encoding="utf-8")
    for rid, record in records.items():
        if str(record["file"]) not in text:
            errors.append(f"ADR index missing {rid}: {record['file']}")
    for token in ("ADR_SUPERSESSION_POLICY.md", "ADR_TEMPLATE.md", "ADR_REGISTRY.json"):
        if token not in text:
            errors.append(f"ADR index missing governance reference: {token}")

for required in ("ADR_SUPERSESSION_POLICY.md", "ADR_TEMPLATE.md"):
    if not (ROOT / required).exists():
        errors.append(f"missing ADR governance file: {required}")

# Release-truth baseline contract.
for required in (
    "RELEASE_TRUTH_DASHBOARD.md",
    "tools/generate_release_truth_dashboard.py",
    "tools/check_release_truth_drift.py",
    "RELEASE_EVIDENCE_TEMPLATE.json",
):
    if not (ROOT / required).exists():
        errors.append(f"missing release-truth artifact: {required}")

dashboard = ROOT / "RELEASE_TRUTH_DASHBOARD.md"
if dashboard.exists():
    text = dashboard.read_text(encoding="utf-8")
    if "Overall candidate state: ⏸️ HOLD" not in text:
        errors.append("checked-in baseline release dashboard must remain HOLD")
    if "Source/docs/code presence alone never produces PASS." not in text:
        errors.append("release dashboard missing anti-inference truth rule")
    for marker in (
        "RELEASE_TRUTH_SCHEMA",
        "RELEASE_TRUTH_EVIDENCE_SHA256",
        "RELEASE_TRUTH_FINGERPRINT",
        "RELEASE_TRUTH_OVERALL",
    ):
        if marker not in text:
            errors.append(f"release dashboard missing deterministic marker: {marker}")

generator = ROOT / "tools" / "generate_release_truth_dashboard.py"
template = ROOT / "RELEASE_EVIDENCE_TEMPLATE.json"
if generator.exists() and template.exists():
    try:
        spec = importlib.util.spec_from_file_location("gpt_ea_release_truth", generator)
        if spec is None or spec.loader is None:
            raise RuntimeError("could not load generator module")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        data = json.loads(template.read_text(encoding="utf-8"))
        rows, overall, blockers = module.assess(data)
        if overall != module.HOLD:
            errors.append(f"default release evidence template must assess as HOLD, got {overall}")
        if any(r.get("status") == module.PASS for r in rows):
            errors.append("default release evidence template must not create PASS dashboard rows")
        if any(r.get("status") == module.NOGO for r in rows):
            errors.append("default placeholder template should be HOLD, not NO-GO, absent explicit failures")
    except Exception as exc:
        errors.append(f"could not execute release-truth assessment: {exc}")

readme = ROOT / "README.md"
if readme.exists():
    text = readme.read_text(encoding="utf-8")
    for token in ("ADR_INDEX.md", "ADR_SUPERSESSION_POLICY.md", "RELEASE_TRUTH_DASHBOARD.md"):
        if token not in text:
            errors.append(f"README missing governance link: {token}")

architecture = ROOT / "ARCHITECTURE.md"
if architecture.exists():
    text = architecture.read_text(encoding="utf-8")
    for token in ("ADR_INDEX.md", "ADR_SUPERSESSION_POLICY.md", "RELEASE_TRUTH_DASHBOARD.md"):
        if token not in text:
            errors.append(f"ARCHITECTURE.md missing governance link: {token}")

if errors:
    print("ARCHITECTURE / RELEASE-TRUTH CHECK: FAILED")
    for error in errors:
        print("ERROR:", error)
    sys.exit(1)

print(f"ARCHITECTURE / RELEASE-TRUTH CHECK: PASS ({len(records)} ADRs)")

#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

adr_files = [
    "ADR_001_FAIL_CLOSED_NEW_ENTRY_GOVERNANCE.md",
    "ADR_002_CUSTOMER_OWNED_OPENAI_API_KEYS.md",
    "ADR_003_HUMAN_APPROVAL_BEFORE_EXECUTION.md",
    "ADR_004_EXISTING_POSITION_SAFETY_DURING_BLOCKS.md",
    "ADR_005_EVIDENCE_BOUND_RELEASES.md",
    "ADR_006_VERSIONED_LEGAL_RISK_PRIVACY_ACK.md",
    "ADR_007_PRIVACY_MINIMIZED_LICENSING_TELEMETRY.md",
    "ADR_008_SHADOW_FIRST_ADAPTIVE_LEARNING.md",
]

index = ROOT / "ADR_INDEX.md"
if not index.exists():
    errors.append("ADR_INDEX.md missing")
else:
    text = index.read_text(encoding="utf-8")
    for name in adr_files:
        if name not in text:
            errors.append(f"ADR index missing link/reference: {name}")

for name in adr_files:
    p = ROOT / name
    if not p.exists():
        errors.append(f"missing ADR: {name}")
        continue
    text = p.read_text(encoding="utf-8")
    if "**Status:** Accepted" not in text:
        errors.append(f"{name}: status must be explicitly Accepted")
    for heading in ("## 🎯 Context", "## ✅ Decision", "## 🧠 Rationale", "## ⚖️ Consequences", "## 🔀 Alternatives considered"):
        if heading not in text:
            errors.append(f"{name}: missing ADR section {heading}")

for required in [
    "RELEASE_TRUTH_DASHBOARD.md",
    "tools/generate_release_truth_dashboard.py",
    "RELEASE_EVIDENCE_TEMPLATE.json",
]:
    if not (ROOT / required).exists():
        errors.append(f"missing release-truth artifact: {required}")

dashboard = ROOT / "RELEASE_TRUTH_DASHBOARD.md"
if dashboard.exists():
    text = dashboard.read_text(encoding="utf-8")
    if "Overall candidate state: ⏸️ HOLD" not in text:
        errors.append("checked-in baseline release dashboard must remain HOLD")
    if "Source/docs/code presence alone never produces PASS." not in text:
        errors.append("release dashboard missing anti-inference truth rule")

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
    for token in ("ADR_INDEX.md", "RELEASE_TRUTH_DASHBOARD.md"):
        if token not in text:
            errors.append(f"README missing governance link: {token}")

architecture = ROOT / "ARCHITECTURE.md"
if architecture.exists():
    text = architecture.read_text(encoding="utf-8")
    if "ADR_INDEX.md" not in text:
        errors.append("ARCHITECTURE.md must link to ADR_INDEX.md")

if errors:
    print("ARCHITECTURE / RELEASE-TRUTH CHECK: FAILED")
    for error in errors:
        print("ERROR:", error)
    sys.exit(1)

print("ARCHITECTURE / RELEASE-TRUTH CHECK: PASS")

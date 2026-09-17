#!/usr/bin/env python3
from __future__ import annotations
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MARKER="<!-- GPT_EA_DOC_HEADER -->"
required_links=[
    "(README.md)",
    "(ARCHITECTURE.md)",
    "(ROADMAP.md)",
    "(PRIVACY_DATA_RETENTION_REVIEW.md)",
    "(RELEASE_EVIDENCE_PACK.md)",
]
errors=[]
files=sorted(ROOT.rglob("*.md"))

for p in files:
    rel=p.relative_to(ROOT).as_posix()
    text=p.read_text(encoding="utf-8")
    if MARKER not in text:
        errors.append(f"{rel}: missing GPT_EA documentation header marker")
        continue
    if "🧠⚡ GPT_EA" not in text:
        errors.append(f"{rel}: missing GPT_EA logo lockup")
    # Central branded navigation is required on repository documentation.
    for link in required_links:
        if link not in text:
            errors.append(f"{rel}: missing navigation link {link}")

for required in [
    "ARCHITECTURE.md",
    "ROADMAP.md",
    "PRIVACY_DATA_RETENTION_REVIEW.md",
    "RELEASE_EVIDENCE_PACK.md",
]:
    if not (ROOT/required).exists():
        errors.append(f"missing central documentation: {required}")

if errors:
    print("DOCUMENTATION BRANDING CHECK: FAILED")
    for e in errors:
        print("ERROR:",e)
    sys.exit(1)

print(f"DOCUMENTATION BRANDING CHECK: PASS ({len(files)} markdown files)")

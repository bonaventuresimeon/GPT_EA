#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from release_contract import load_release_contract

ROOT = Path(__file__).resolve().parents[1]
CONTRACT=load_release_contract()
SCHEMA = CONTRACT["compile_evidence_schema"]
SHA40 = re.compile(r"^[0-9a-fA-F]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def fail(msg: str) -> None:
    print("COMPILE EVIDENCE: FAILED")
    print("ERROR:", msg)
    raise SystemExit(1)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python tools/validate_compile_evidence.py <compile-evidence.json>")
        return 2

    record_path = Path(sys.argv[1]).resolve()
    if not record_path.exists():
        fail("compile evidence file not found")

    try:
        rec = json.loads(record_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"invalid JSON: {exc}")

    if rec.get("schema_version") != SCHEMA:
        fail("schema_version mismatch")
    if not str(rec.get("release_id", "")).strip():
        fail("release_id missing")
    if len(str(rec.get("evidence_id", "")).strip()) < 6:
        fail("evidence_id missing/too short")
    if not SHA40.fullmatch(str(rec.get("git_sha", ""))):
        fail("git_sha must be exactly 40 hexadecimal characters")
    if not str(rec.get("branch", "")).strip():
        fail("branch missing")

    try:
        datetime.fromisoformat(str(rec.get("compiled_at_utc", "")).replace("Z", "+00:00"))
    except Exception:
        fail("compiled_at_utc must be ISO-8601")

    for key in ("windows_version", "windows_arch", "metaeditor_build", "mt5_build", "source_path"):
        if not str(rec.get(key, "")).strip():
            fail(f"{key} missing")

    if rec.get("compile_errors") != 0:
        fail("compile_errors must be 0")
    if rec.get("compile_warnings") != 0:
        fail("compile_warnings must be 0 for production")
    if rec.get("smoke_load_passed") is not True:
        fail("smoke_load_passed must be true")
    if rec.get("init_critical_errors") != 0:
        fail("init_critical_errors must be 0")
    if rec.get("secrets_exposed") != 0:
        fail("secrets_exposed must be 0")
    if rec.get("source_unchanged_after_compile") is not True:
        fail("source_unchanged_after_compile must be true")

    def resolve(value: str) -> Path:
        p = Path(value)
        if p.is_absolute():
            return p
        return (ROOT / p).resolve()

    log_path = resolve(str(rec.get("compile_log_path", "")))
    if not log_path.exists() or not log_path.is_file():
        fail("compile log file does not exist")
    log_digest = str(rec.get("compile_log_sha256", "")).lower()
    if not SHA64.fullmatch(log_digest):
        fail("compile_log_sha256 must be 64 lowercase hex characters")
    if sha256(log_path) != log_digest:
        fail("compile_log_sha256 mismatch")

    ex5_path = resolve(str(rec.get("ex5_path", "")))
    if not ex5_path.exists() or not ex5_path.is_file():
        fail("EX5 artifact does not exist")
    ex5_digest = str(rec.get("ex5_sha256", "")).lower()
    if not SHA64.fullmatch(ex5_digest):
        fail("ex5_sha256 must be 64 lowercase hex characters")
    if sha256(ex5_path) != ex5_digest:
        fail("EX5 SHA-256 mismatch")

    set_digest = str(rec.get("set_sha256", ""))
    set_path_text = str(rec.get("set_path", "")).strip()
    if set_digest == "NONE":
        if set_path_text:
            fail("set_path must be empty when set_sha256 is NONE")
    else:
        set_digest = set_digest.lower()
        if not SHA64.fullmatch(set_digest):
            fail("set_sha256 must be 64 lowercase hex characters or NONE")
        if not set_path_text:
            fail("set_path required when set_sha256 is not NONE")
        set_path = resolve(set_path_text)
        if not set_path.exists() or not set_path.is_file():
            fail("SET artifact does not exist")
        if sha256(set_path) != set_digest:
            fail("SET SHA-256 mismatch")

    supplied = str(rec.get("evidence_digest", "")).lower()
    if not SHA64.fullmatch(supplied):
        fail("evidence_digest must be 64 lowercase hex characters")

    basis = dict(rec)
    basis.pop("evidence_digest", None)
    raw = json.dumps(basis, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    digest = hashlib.sha256(raw).hexdigest()
    if supplied != digest:
        fail("evidence_digest mismatch")

    print("COMPILE EVIDENCE: PASS")
    print("EVIDENCE_DIGEST=" + digest)
    print("EX5_SHA256=" + ex5_digest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

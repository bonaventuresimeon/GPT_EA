#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

ROOT=Path(__file__).resolve().parents[1]
HEX40=re.compile(r"^[0-9a-fA-F]{40}$")
HEX64=re.compile(r"^[0-9a-fA-F]{64}$")

def resolve(value:str)->Path:
    p=Path(value)
    return p if p.is_absolute() else ROOT/p

def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def validate_rollback_readiness(value:dict[str,Any])->list[str]:
    errors:list[str]=[]
    mode=str(value.get("mode",""))
    if mode not in {"VALIDATED_PACKAGE","FIRST_CERTIFIED_RELEASE"}:
        errors.append("rollback_package.mode must be VALIDATED_PACKAGE or FIRST_CERTIFIED_RELEASE")
        return errors

    if mode=="VALIDATED_PACKAGE":
        prev_id=str(value.get("previous_release_validation_id","")).strip()
        prev_sha=str(value.get("previous_git_sha","")).strip()
        package_raw=str(value.get("package_path","")).strip()
        package_digest=str(value.get("package_sha256","")).strip()
        validation_raw=str(value.get("validation_path","")).strip()
        if len(prev_id)<8: errors.append("rollback_package.previous_release_validation_id is required")
        if not HEX40.fullmatch(prev_sha): errors.append("rollback_package.previous_git_sha must be 40 hex")
        if not package_raw: errors.append("rollback_package.package_path is required")
        if not HEX64.fullmatch(package_digest): errors.append("rollback_package.package_sha256 must be SHA-256")
        if value.get("validated") is not True: errors.append("rollback_package.validated must be true")
        if str(value.get("first_release_justification","")).strip():
            errors.append("first_release_justification must be blank for VALIDATED_PACKAGE")
        if package_raw:
            p=resolve(package_raw)
            if not p.exists(): errors.append(f"rollback package not found: {p}")
            elif HEX64.fullmatch(package_digest) and sha256_file(p).lower()!=package_digest.lower():
                errors.append("rollback package SHA-256 mismatch")
        if not validation_raw:
            errors.append("rollback_package.validation_path is required")
        else:
            p=resolve(validation_raw)
            if not p.exists(): errors.append(f"rollback validation output not found: {p}")
            elif "ROLLBACK PACKAGE VALIDATION: PASS" not in p.read_text(encoding="utf-8",errors="replace"):
                errors.append("rollback validation output does not contain PASS")
    else:
        justification=str(value.get("first_release_justification","")).strip()
        if len(justification)<40:
            errors.append("FIRST_CERTIFIED_RELEASE requires a >=40 character justification")
        for key in ("previous_release_validation_id","previous_git_sha","package_path"):
            if str(value.get(key,"")).strip():
                errors.append(f"rollback_package.{key} must be blank for FIRST_CERTIFIED_RELEASE")
        if value.get("validated") is not True:
            errors.append("rollback_package.validated must be true after explicit first-release operator review")
        digest=str(value.get("package_sha256",""))
        if digest not in {"","0"*64}:
            errors.append("rollback_package.package_sha256 must be blank/zero for FIRST_CERTIFIED_RELEASE")
    return errors

def main()->int:
    ap=argparse.ArgumentParser(description="Validate GPT_EA rollback readiness in release evidence")
    ap.add_argument("evidence",nargs="?",default="release_evidence.json")
    args=ap.parse_args()
    p=resolve(args.evidence)
    if not p.exists():
        print(f"ROLLBACK READINESS: FAILED\nERROR: evidence not found: {p}"); return 1
    data=json.loads(p.read_text(encoding="utf-8"))
    value=data.get("rollback_package")
    if not isinstance(value,dict):
        print("ROLLBACK READINESS: FAILED\nERROR: rollback_package must be an object"); return 1
    errors=validate_rollback_readiness(value)
    out=ROOT/"rollback-readiness-validation.txt"
    if errors:
        text="ROLLBACK READINESS: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+"\n"
        out.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    text=f"ROLLBACK READINESS: PASS\nMODE: {value.get('mode')}\n"
    out.write_text(text,encoding="utf-8"); print(text,end=""); return 0

if __name__=="__main__":
    raise SystemExit(main())

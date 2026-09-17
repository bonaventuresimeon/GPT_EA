#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path

def digest_bytes(b:bytes)->str: return hashlib.sha256(b).hexdigest()

def main()->int:
    ap=argparse.ArgumentParser(description="Validate GPT_EA certified rollback ZIP")
    ap.add_argument("package")
    args=ap.parse_args()
    p=Path(args.package)
    if not p.exists():
        print("ROLLBACK PACKAGE VALIDATION: FAILED\nERROR: package not found"); return 1
    errors=[]
    with zipfile.ZipFile(p,"r") as z:
        names=set(z.namelist())
        if "rollback-manifest.json" not in names:
            errors.append("rollback-manifest.json missing")
            manifest={}
        else:
            manifest=json.loads(z.read("rollback-manifest.json"))
        if manifest.get("schema_version")!="rollback_package_manifest_v1":
            errors.append("schema_version mismatch")
        if len(str(manifest.get("source_git_sha","")))!=40:
            errors.append("source_git_sha invalid")
        migration=str(manifest.get("migration_note",""))
        if migration not in names: errors.append("migration note missing from ZIP")
        files=manifest.get("files",[])
        if not isinstance(files,list) or len(files)<3: errors.append("manifest must contain at least 3 files")
        seen=set()
        for e in files if isinstance(files,list) else []:
            arc=str(e.get("archive_path","")); expected=str(e.get("sha256",""))
            if arc in seen: errors.append("duplicate archive path: "+arc)
            seen.add(arc)
            if arc not in names: errors.append("archived file missing: "+arc); continue
            b=z.read(arc)
            if digest_bytes(b).lower()!=expected.lower(): errors.append("SHA-256 mismatch: "+arc)
            if len(b)!=int(e.get("size",-1)): errors.append("size mismatch: "+arc)
    package_sha=hashlib.sha256(p.read_bytes()).hexdigest()
    if errors:
        print("ROLLBACK PACKAGE VALIDATION: FAILED")
        for e in errors: print("ERROR:",e)
        print("PACKAGE_SHA256:",package_sha)
        return 1
    print("ROLLBACK PACKAGE VALIDATION: PASS")
    print("PACKAGE_SHA256:",package_sha)
    return 0

if __name__=="__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT=Path(__file__).resolve().parents[1]

def sha256_file(p:Path)->str:
    h=hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def resolve(base:Path,value:str)->Path:
    p=Path(value)
    if p.is_absolute(): return p
    a=base/p
    if a.exists(): return a
    return ROOT/p

def collect_paths(value:Any,out:list[str])->None:
    if isinstance(value,dict):
        for k,v in value.items():
            if k.endswith("_path") and isinstance(v,str) and v.strip(): out.append(v.strip())
            collect_paths(v,out)
    elif isinstance(value,list):
        for x in value: collect_paths(x,out)

def main()->int:
    ap=argparse.ArgumentParser(description="Build GPT_EA certified rollback ZIP")
    ap.add_argument("--release-evidence",required=True)
    ap.add_argument("--migration-note",required=True)
    ap.add_argument("--final-review",default="")
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    evidence=Path(args.release_evidence).resolve()
    note=Path(args.migration_note).resolve()
    if not evidence.exists() or not note.exists():
        print("ROLLBACK PACKAGE BUILD: FAILED")
        if not evidence.exists(): print("ERROR: release evidence missing:",evidence)
        if not note.exists(): print("ERROR: migration note missing:",note)
        return 1
    if len(note.read_text(encoding="utf-8",errors="replace").strip())<100:
        print("ROLLBACK PACKAGE BUILD: FAILED\nERROR: migration note is too short")
        return 1

    data=json.loads(evidence.read_text(encoding="utf-8"))
    release_id=str(data.get("release_validation_id",""))
    git_sha=str(data.get("build",{}).get("git_sha",""))
    if len(release_id)<8 or len(git_sha)!=40:
        print("ROLLBACK PACKAGE BUILD: FAILED\nERROR: invalid release identity")
        return 1

    refs:list[str]=[]
    collect_paths(data,refs)
    paths=[evidence,note]
    if args.final_review:
        paths.append(Path(args.final_review).resolve())
    for raw in refs:
        p=resolve(evidence.parent,raw)
        if not p.exists():
            print(f"ROLLBACK PACKAGE BUILD: FAILED\nERROR: referenced artifact missing: {raw} -> {p}")
            return 1
        paths.append(p.resolve())

    unique:dict[str,Path]={}
    for p in paths:
        unique[str(p)]=p
    if len(unique)<3:
        print("ROLLBACK PACKAGE BUILD: FAILED\nERROR: too few rollback artifacts")
        return 1

    entries=[]
    used=set()
    for p in unique.values():
        name=p.name
        arc=f"evidence/{name}"
        if arc in used:
            arc=f"evidence/{sha256_file(p)[:10]}-{name}"
        used.add(arc)
        entries.append({"archive_path":arc,"source_path":str(p),"sha256":sha256_file(p),"size":p.stat().st_size})

    manifest={
        "schema_version":"rollback_package_manifest_v1",
        "release_validation_id":release_id,
        "source_git_sha":git_sha,
        "created_utc":datetime.now(timezone.utc).isoformat(),
        "migration_note":next(e["archive_path"] for e in entries if Path(e["source_path"])==note),
        "files":entries,
    }

    out=Path(args.output).resolve(); out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(out,"w",compression=zipfile.ZIP_DEFLATED) as z:
        for e in entries: z.write(e["source_path"],e["archive_path"])
        z.writestr("rollback-manifest.json",json.dumps(manifest,indent=2)+"\n")
    digest=sha256_file(out)
    out.with_suffix(out.suffix+".sha256").write_text(digest+"  "+out.name+"\n",encoding="utf-8")
    print("ROLLBACK PACKAGE BUILD: PASS")
    print("PACKAGE:",out)
    print("PACKAGE_SHA256:",digest)
    return 0

if __name__=="__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA="gpt_ea_release_evidence_pack_v1"
SHA40=re.compile(r"^[a-fA-F0-9]{40}$")
SECRET_PATTERNS=[
    re.compile(rb"sk-[A-Za-z0-9_\-]{20,}"),
    re.compile(rb"Authorization:\s*Bearer\s+[A-Za-z0-9._\-]{20,}",re.I),
    re.compile(rb"X-GPT-EA-Token:\s*[A-Za-z0-9._\-]{12,}",re.I),
    re.compile(rb"InpOpenAIAPIKey\s*=\s*[^\s;]{20,}",re.I),
]

def sha256(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def secret_hits(path:Path)->list[str]:
    try:
        data=path.read_bytes()
    except Exception:
        return []
    hits=[]
    for pat in SECRET_PATTERNS:
        if pat.search(data):
            hits.append(pat.pattern.decode("utf-8","ignore"))
    return hits

def main()->int:
    ap=argparse.ArgumentParser(description="Build a hashed GPT_EA release-evidence pack from an explicit artifact manifest.")
    ap.add_argument("config",type=Path)
    ap.add_argument("--output",type=Path,default=None)
    args=ap.parse_args()

    cfg=json.loads(args.config.read_text(encoding="utf-8"))
    if cfg.get("pack_schema")!=SCHEMA:
        print("ERROR: unsupported pack_schema")
        return 2

    release_id=str(cfg.get("release_id","")).strip()
    git_sha=str(cfg.get("git_sha","")).strip()
    if not release_id:
        print("ERROR: release_id is required")
        return 2
    if not SHA40.fullmatch(git_sha):
        print("ERROR: git_sha must be exactly 40 hexadecimal characters")
        return 2

    source_root=Path(cfg.get("source_root",".")).resolve()
    out=(args.output or Path(cfg.get("output_directory") or f"GPT_EA_RELEASE_{release_id}")).resolve()
    if out.exists():
        print(f"ERROR: output already exists: {out}")
        return 2
    out.mkdir(parents=True)

    index=[]
    errors=[]
    for item in cfg.get("artifacts",[]):
        rel=str(item.get("path","")).strip()
        etype=str(item.get("evidence_type","unspecified")).strip()
        required=bool(item.get("required",True))
        if not rel:
            errors.append("artifact entry has empty path")
            continue
        src=(source_root/rel).resolve()
        try:
            src.relative_to(source_root)
        except ValueError:
            errors.append(f"artifact escapes source_root: {rel}")
            continue
        if not src.exists() or not src.is_file():
            if required:
                errors.append(f"missing required artifact: {rel}")
            continue

        hits=secret_hits(src)
        if hits:
            errors.append(f"secret-like material detected in {rel}: {', '.join(hits)}")
            continue

        dest=out/rel
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(src,dest)
        index.append({
            "relative_path":rel.replace("\\","/"),
            "sha256":sha256(dest),
            "size_bytes":dest.stat().st_size,
            "evidence_type":etype,
            "timestamp_utc":datetime.now(timezone.utc).isoformat(),
        })

    if errors:
        shutil.rmtree(out,ignore_errors=True)
        print("RELEASE EVIDENCE PACK: FAILED")
        for e in errors:
            print("ERROR:",e)
        return 1

    metadata={
        "pack_schema":SCHEMA,
        "release_id":release_id,
        "git_sha":git_sha.lower(),
        "generated_at_utc":datetime.now(timezone.utc).isoformat(),
        "artifact_count":len(index),
    }
    (out/"pack-metadata.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")
    index_path=out/"archive-index.json"
    index_path.write_text(json.dumps(index,indent=2)+"\n",encoding="utf-8")

    text_index=out/"archive-index.txt"
    with text_index.open("w",encoding="utf-8") as f:
        f.write("relative_path | sha256 | size_bytes | evidence_type | timestamp_utc\n")
        for x in index:
            f.write(f"{x['relative_path']} | {x['sha256']} | {x['size_bytes']} | {x['evidence_type']} | {x['timestamp_utc']}\n")

    manifest_hash=sha256(index_path)
    (out/"evidence-pack-manifest.sha256").write_text(manifest_hash+"  archive-index.json\n",encoding="utf-8")

    print("RELEASE EVIDENCE PACK: PASS")
    print(f"OUTPUT={out}")
    print(f"ARTIFACTS={len(index)}")
    print(f"MANIFEST_SHA256={manifest_hash}")
    print("NOTE: pack creation does not imply MetaEditor, tester, soak or legal evidence passed; it only packages supplied evidence.")
    return 0

if __name__=="__main__":
    raise SystemExit(main())

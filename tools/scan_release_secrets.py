#!/usr/bin/env python3
from __future__ import annotations
import argparse, re, sys
from pathlib import Path

PATTERNS=[
    ("OPENAI_LIKE_KEY",re.compile(rb"\bsk-[A-Za-z0-9_\-]{20,}\b")),
    ("AUTH_BEARER",re.compile(rb"Authorization\s*:\s*Bearer\s+[A-Za-z0-9._\-]{20,}",re.I)),
    ("PROXY_TOKEN",re.compile(rb"X-GPT-EA-Token\s*:\s*[A-Za-z0-9._\-]{12,}",re.I)),
    ("PRIVATE_KEY",re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("OPENAI_INPUT_VALUE",re.compile(rb"InpOpenAIAPIKey\s*=\s*(?!<|$|\s*$)[^\r\n;]{12,}",re.I)),
    ("PASSWORD_ASSIGNMENT",re.compile(rb"(?:mt5_?|account_?|broker_?)password\s*[=:]\s*[^\s\r\n]{8,}",re.I)),
]
SKIP_DIRS={".git","__pycache__",".venv","venv","node_modules"}

def files(paths:list[Path]):
    for p in paths:
        if p.is_file():
            yield p
        elif p.is_dir():
            for x in p.rglob("*"):
                if x.is_file() and not any(part in SKIP_DIRS for part in x.parts):
                    yield x

def main()->int:
    ap=argparse.ArgumentParser(description="Scan GPT_EA source/release artifacts for secret-like material.")
    ap.add_argument("paths",nargs="*",default=["GPT_EA.mq5","docs","COMMERCIAL_LICENSE.md"])
    args=ap.parse_args()
    root=Path.cwd()
    hits=[]
    for p in files([Path(x) for x in args.paths]):
        try:
            data=p.read_bytes()
        except Exception:
            continue
        # Avoid huge opaque binaries; EX5 identity is handled by hashes.
        if len(data)>8_000_000:
            continue
        for name,pat in PATTERNS:
            if pat.search(data):
                hits.append((p.as_posix(),name))
        # Input documentation may contain placeholders; only flag a plausible
        # concrete value, never <YOUR KEY>, blank, or the harmless proxy marker.
        for m in re.finditer(rb"InpOpenAIAPIKey\s*=\s*([^\r\n;]+)",data,re.I):
            value=m.group(1).strip()
            upper=value.upper()
            if not value or value.startswith(b"<") or b"YOUR" in upper or value==b"PROXY_TRANSPORT_ACTIVE":
                continue
            if len(value)>=20:
                hits.append((p.as_posix(),"OPENAI_INPUT_VALUE"))
    if hits:
        print("RELEASE SECRET SCAN: FAILED")
        for path,name in hits:
            print(f"ERROR: {name} detected in {path}")
        return 1
    print("RELEASE SECRET SCAN: PASS")
    return 0

if __name__=="__main__": raise SystemExit(main())

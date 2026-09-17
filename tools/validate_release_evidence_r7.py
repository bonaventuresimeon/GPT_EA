#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from validate_api_transport_evidence import validate_api_transport

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"release-evidence-validation-r7.txt"


def main() -> int:
    evidence=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/"release_evidence.json"
    if not evidence.is_absolute():
        evidence=ROOT/evidence
    if not evidence.exists():
        text=f"R7 RELEASE EVIDENCE: FAILED\nERROR: evidence file not found: {evidence}\n"
        OUT.write_text(text,encoding="utf-8"); print(text,end=""); return 1
    try:
        data=json.loads(evidence.read_text(encoding="utf-8"))
    except Exception as exc:
        text=f"R7 RELEASE EVIDENCE: FAILED\nERROR: invalid JSON: {exc}\n"
        OUT.write_text(text,encoding="utf-8"); print(text,end=""); return 1

    api_errors,api_digest=validate_api_transport(data)
    if api_errors:
        text="R7 RELEASE EVIDENCE: FAILED\n"+"\n".join(f"ERROR: {e}" for e in api_errors)+f"\nAPI_TRANSPORT_SHA256: {api_digest}\n"
        OUT.write_text(text,encoding="utf-8"); print(text,end=""); return 1

    base=ROOT/"tools"/"validate_release_evidence.py"
    proc=subprocess.run([sys.executable,str(base),str(evidence)],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=False)
    if proc.returncode!=0:
        text="R7 RELEASE EVIDENCE: FAILED\nBASE_R6_VALIDATOR_FAILED\n"+proc.stdout+f"API_TRANSPORT_SHA256: {api_digest}\n"
        OUT.write_text(text,encoding="utf-8"); print(text,end=""); return 1

    text="R7 RELEASE EVIDENCE: PASS\n"+proc.stdout+f"API_TRANSPORT_SHA256: {api_digest}\n"
    OUT.write_text(text,encoding="utf-8")
    print(text,end="")
    return 0


if __name__=="__main__":
    raise SystemExit(main())

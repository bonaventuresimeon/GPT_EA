#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def canonical_digest(value: dict) -> str:
    payload=json.dumps(value,sort_keys=True,separators=(",",":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def require(errors: list[str], cond: bool, msg: str) -> None:
    if not cond:
        errors.append(msg)


def validate_api_transport(data: dict) -> tuple[list[str], str]:
    errors: list[str]=[]
    api=data.get("api_transport")
    if not isinstance(api,dict):
        return ["api_transport must be an object"],""

    require(errors,api.get("schema_version")=="api_transport_evidence_v1",
            "api_transport.schema_version must be api_transport_evidence_v1")
    require(errors,api.get("mode") in {"DIRECT_OPENAI","SECURE_PROXY"},
            "api_transport.mode must be DIRECT_OPENAI or SECURE_PROXY")
    require(errors,bool(str(api.get("endpoint_host","")).strip()),
            "api_transport.endpoint_host is required")
    require(errors,api.get("https_required") is True,
            "api_transport.https_required must be true")
    require(errors,api.get("webrequest_allow_list_verified") is True,
            "api_transport.webrequest_allow_list_verified must be true")
    require(errors,api.get("high_priority_matrix_passed") is True,
            "api_transport.high_priority_matrix_passed must be true")
    require(errors,api.get("deep_review_path_passed") is True,
            "api_transport.deep_review_path_passed must be true")
    require(errors,api.get("web_search_path_passed") is True,
            "api_transport.web_search_path_passed must be true")
    require(errors,api.get("failure_recovery_tested") is True,
            "api_transport.failure_recovery_tested must be true")
    require(errors,api.get("request_id_trace_tested") is True,
            "api_transport.request_id_trace_tested must be true")
    try:
        leaks=int(api.get("secret_leak_count",-1))
    except Exception:
        leaks=-1
    require(errors,leaks==0,"api_transport.secret_leak_count must be 0")

    evidence_raw=str(api.get("evidence_path","")).strip()
    require(errors,bool(evidence_raw),"api_transport.evidence_path is required")
    if evidence_raw:
        path=Path(evidence_raw)
        if not path.is_absolute():
            path=ROOT/path
        require(errors,path.exists(),f"API transport evidence file not found: {path}")

    gates=data.get("gates",{})
    require(errors,isinstance(gates,dict) and gates.get("api_transport") is True,
            "gates.api_transport must be true")

    return errors,canonical_digest(api)


def main() -> int:
    evidence=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/"release_evidence.json"
    if not evidence.is_absolute():
        evidence=ROOT/evidence
    if not evidence.exists():
        print(f"API TRANSPORT EVIDENCE: FAILED\nERROR: evidence file not found: {evidence}")
        return 1
    try:
        data=json.loads(evidence.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"API TRANSPORT EVIDENCE: FAILED\nERROR: invalid JSON: {exc}")
        return 1

    errors,digest=validate_api_transport(data)
    out=ROOT/"api-transport-evidence-validation.txt"
    if errors:
        text="API TRANSPORT EVIDENCE: FAILED\n"+"\n".join(f"ERROR: {e}" for e in errors)+f"\nAPI_TRANSPORT_SHA256: {digest}\n"
        out.write_text(text,encoding="utf-8")
        print(text,end="")
        return 1
    text=f"API TRANSPORT EVIDENCE: PASS\nAPI_TRANSPORT_SHA256: {digest}\n"
    out.write_text(text,encoding="utf-8")
    print(text,end="")
    return 0


if __name__=="__main__":
    raise SystemExit(main())

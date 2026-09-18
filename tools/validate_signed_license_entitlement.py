#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def fail(msg: str) -> None:
    print("SIGNED LICENSE ENTITLEMENT: FAILED")
    print("ERROR:", msg)
    raise SystemExit(1)


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def canonical_payload(record: dict) -> bytes:
    basis = dict(record)
    basis.pop("signature_base64", None)
    return json.dumps(basis, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate GPT_EA signed entitlement structure and optionally verify Ed25519 signature.")
    ap.add_argument("entitlement")
    ap.add_argument("--public-key", help="PEM Ed25519 public key used to verify the entitlement signature")
    ap.add_argument("--allow-expired", action="store_true", help="structure/signature validation only; do not fail on expiry")
    args = ap.parse_args()

    p = Path(args.entitlement)
    if not p.exists():
        fail("entitlement file not found")
    try:
        rec = json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"invalid JSON: {exc}")

    required = [
        "schema_version","license_id","product","entitlement_version","issued_at_utc",
        "expires_at_utc","offline_grace_until_utc","release_scope","account_scope",
        "server_scope","key_id","signature_algorithm","signature_base64",
    ]
    for key in required:
        if key not in rec:
            fail(f"missing field: {key}")

    if rec["schema_version"] != "gpt_ea_signed_entitlement_v1":
        fail("schema_version mismatch")
    if rec["product"] != "GPT_EA":
        fail("product must be GPT_EA")
    if not isinstance(rec["entitlement_version"], int) or rec["entitlement_version"] < 1:
        fail("entitlement_version must be >= 1")
    if rec["signature_algorithm"] != "Ed25519":
        fail("signature_algorithm must be Ed25519")
    if len(str(rec["license_id"]).strip()) < 8:
        fail("license_id too short")
    for key in ("release_scope","account_scope","server_scope"):
        if not isinstance(rec[key], list) or not rec[key] or not all(str(x).strip() for x in rec[key]):
            fail(f"{key} must be a non-empty list")

    try:
        issued = parse_time(str(rec["issued_at_utc"]))
        expires = parse_time(str(rec["expires_at_utc"]))
        grace = parse_time(str(rec["offline_grace_until_utc"]))
    except Exception:
        fail("issued/expires/grace times must be ISO-8601")
    if not (issued < expires <= grace):
        fail("time ordering must be issued_at < expires_at <= offline_grace_until")
    if not args.allow_expired and datetime.now(timezone.utc) > grace.astimezone(timezone.utc):
        fail("offline grace period has expired")

    try:
        signature = base64.b64decode(str(rec["signature_base64"]), validate=True)
    except Exception:
        fail("signature_base64 is not valid base64")
    if len(signature) != 64:
        fail("Ed25519 signature must decode to 64 bytes")

    if args.public_key:
        key_path = Path(args.public_key)
        if not key_path.exists():
            fail("public key file not found")
        try:
            from cryptography.hazmat.primitives import serialization
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
        except Exception:
            fail("cryptography package is required for --public-key verification")
        try:
            public_key = serialization.load_pem_public_key(key_path.read_bytes())
            if not isinstance(public_key, Ed25519PublicKey):
                fail("public key is not Ed25519")
            public_key.verify(signature, canonical_payload(rec))
        except SystemExit:
            raise
        except Exception as exc:
            fail(f"signature verification failed: {exc}")
        print("SIGNATURE_VERIFIED=true")
    else:
        print("SIGNATURE_VERIFIED=false")
        print("NOTE: structure validated only; use --public-key for cryptographic verification")

    print("SIGNED LICENSE ENTITLEMENT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

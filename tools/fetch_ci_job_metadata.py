#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = "github_actions_job_metadata_v1"


def api_json(url: str, token: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "GPT_EA-CI-Evidence",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser(description="Capture completed GPT_EA GitHub Actions job metadata")
    ap.add_argument("--repository", default=os.getenv("GITHUB_REPOSITORY", ""))
    ap.add_argument("--run-id", type=int, default=int(os.getenv("GITHUB_RUN_ID", "0") or 0))
    ap.add_argument("--run-attempt", type=int, default=int(os.getenv("GITHUB_RUN_ATTEMPT", "0") or 0))
    ap.add_argument("--job-name", default="static-release-gate")
    ap.add_argument("--head-sha", default=os.getenv("GITHUB_SHA", ""))
    ap.add_argument("--output", default="ci-job-metadata.json")
    args = ap.parse_args()

    token = os.getenv("GITHUB_TOKEN", "").strip()
    errors: list[str] = []
    if not token:
        errors.append("GITHUB_TOKEN is required")
    if args.repository != "bonaventuresimeon/GPT_EA":
        errors.append("repository must be bonaventuresimeon/GPT_EA")
    if args.run_id <= 0 or args.run_attempt <= 0:
        errors.append("run ID and attempt must be > 0")
    if len(args.head_sha) != 40:
        errors.append("head SHA must contain 40 characters")
    if errors:
        print("CI JOB METADATA: FAILED")
        for e in errors:
            print("ERROR:", e)
        return 1

    url = f"https://api.github.com/repos/{args.repository}/actions/runs/{args.run_id}/jobs?per_page=100&filter=latest"
    try:
        data = api_json(url, token)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"CI JOB METADATA: FAILED\nERROR: GitHub jobs API request failed: {exc}")
        return 1

    candidates = [j for j in data.get("jobs", []) if j.get("name") == args.job_name]
    if not candidates:
        print(f"CI JOB METADATA: FAILED\nERROR: completed job named {args.job_name!r} was not found in run {args.run_id}")
        return 1
    job = sorted(candidates, key=lambda j: int(j.get("id", 0)), reverse=True)[0]

    steps = job.get("steps") or []
    completed_steps = [
        s for s in steps
        if s.get("status") == "completed" and s.get("conclusion") not in (None, "skipped")
    ]
    meta = {
        "schema_version": SCHEMA_VERSION,
        "captured_utc": datetime.now(timezone.utc).isoformat(),
        "repository": args.repository,
        "run_id": args.run_id,
        "run_attempt": args.run_attempt,
        "run_url": f"https://github.com/{args.repository}/actions/runs/{args.run_id}",
        "head_sha": args.head_sha,
        "job_id": int(job.get("id", 0) or 0),
        "job_name": str(job.get("name", "")),
        "job_url": str(job.get("html_url", "")),
        "status": str(job.get("status", "")),
        "conclusion": str(job.get("conclusion", "")),
        "runner_id": int(job.get("runner_id", 0) or 0),
        "runner_name": str(job.get("runner_name", "")),
        "runner_group_id": int(job.get("runner_group_id", 0) or 0),
        "runner_group_name": str(job.get("runner_group_name", "")),
        "steps_executed": len(completed_steps),
        "steps": [
            {
                "number": int(s.get("number", 0) or 0),
                "name": str(s.get("name", "")),
                "status": str(s.get("status", "")),
                "conclusion": str(s.get("conclusion", "")),
            }
            for s in steps
        ],
    }

    checks = [
        (meta["job_id"] > 0, "job_id must be > 0"),
        (meta["status"] == "completed", "static job must be completed before evidence collection"),
        (meta["conclusion"] == "success", "static job conclusion must be success"),
        (meta["runner_id"] > 0, "runner_id must be > 0"),
        (bool(meta["runner_name"].strip()), "runner_name must be non-empty"),
        (meta["steps_executed"] >= 7, "at least 7 static-job steps must have actually executed"),
    ]
    failures = [msg for ok, msg in checks if not ok]

    out = Path(args.output)
    if not out.is_absolute():
        out = ROOT / out
    out.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    if failures:
        print("CI JOB METADATA: FAILED")
        for e in failures:
            print("ERROR:", e)
        print(f"METADATA_PATH={out}")
        return 1

    print("CI JOB METADATA: PASS")
    print(f"JOB_ID={meta['job_id']}")
    print(f"RUNNER_ID={meta['runner_id']}")
    print(f"STEPS_EXECUTED={meta['steps_executed']}")
    print(f"METADATA_PATH={out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

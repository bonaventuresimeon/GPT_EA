#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, shutil, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CUSTOMER_DOCS=[
    "docs/INSTALLATION.md","docs/USER_INSTALLATION_GUIDE.md","docs/FIRST_RUN_CHECKLIST.md",
    "docs/API_KEY_TROUBLESHOOTING.md","COMMERCIAL_LICENSE.md","docs/TERMS_AND_CONDITIONS.md",
    "docs/TRADING_RISK_DISCLOSURE.md","docs/DISCLAIMER.md","docs/ANTI_PIRACY_LICENSE_ENFORCEMENT.md",
]

def sha256(p:Path)->str:
    h=hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def run(cmd:list[str])->None:
    proc=subprocess.run(cmd,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=False)
    print(proc.stdout,end="")
    if proc.returncode!=0:
        raise SystemExit(proc.returncode)

def main()->int:
    ap=argparse.ArgumentParser(description="Build a customer GPT_EA package only from PASS release evidence.")
    ap.add_argument("--release-evidence",required=True)
    ap.add_argument("--final-review",required=True)
    ap.add_argument("--ex5",required=True)
    ap.add_argument("--set",dest="set_file",default="")
    ap.add_argument("--output",required=True)
    ap.add_argument("--signature-file",default="")
    ap.add_argument("--require-signature",action="store_true")
    args=ap.parse_args()

    evidence=Path(args.release_evidence).resolve()
    review=Path(args.final_review).resolve()
    ex5=Path(args.ex5).resolve()
    set_file=Path(args.set_file).resolve() if args.set_file else None
    out=Path(args.output).resolve()

    for p in (evidence,review,ex5):
        if not p.exists(): raise SystemExit(f"ERROR: missing required file: {p}")
    if set_file and not set_file.exists(): raise SystemExit(f"ERROR: SET file not found: {set_file}")
    if out.exists(): raise SystemExit(f"ERROR: output already exists: {out}")

    run([sys.executable,str(ROOT/"tools/validate_release_evidence_r10.py"),str(evidence)])
    run([sys.executable,str(ROOT/"tools/validate_final_release_review_r10.py"),str(evidence),str(review)])
    run([sys.executable,str(ROOT/"tools/generate_release_truth_dashboard.py"),str(evidence),"--output","RELEASE_TRUTH_DASHBOARD.md","--require-pass"])
    run([sys.executable,str(ROOT/"tools/check_release_truth_drift.py"),str(evidence),"--dashboard","RELEASE_TRUTH_DASHBOARD.md","--output","release-truth-drift-validation.txt"])

    data=json.loads(evidence.read_text(encoding="utf-8"))
    expected_ex5=str(data.get("build",{}).get("ex5_sha256","")).lower()
    actual_ex5=sha256(ex5)
    if expected_ex5!=actual_ex5:
        raise SystemExit("ERROR: EX5 hash does not match release evidence")

    expected_set=str(data.get("build",{}).get("set_sha256","NONE"))
    if expected_set=="NONE":
        if set_file is not None: raise SystemExit("ERROR: evidence declares SET=NONE but --set was supplied")
    else:
        if set_file is None: raise SystemExit("ERROR: certified SET required by release evidence")
        if sha256(set_file)!=expected_set.lower(): raise SystemExit("ERROR: SET hash does not match release evidence")

    sig=Path(args.signature_file).resolve() if args.signature_file else None
    if args.require_signature and (sig is None or not sig.exists()):
        raise SystemExit("ERROR: --require-signature set but no signature file exists")

    scan_paths=[str(ex5)]
    if set_file: scan_paths.append(str(set_file))
    scan_paths += [str(ROOT/p) for p in CUSTOMER_DOCS if (ROOT/p).exists()]
    run([sys.executable,str(ROOT/"tools/scan_release_secrets.py"),*scan_paths])

    out.mkdir(parents=True)
    shutil.copy2(ex5,out/"GPT_EA.ex5")
    if set_file: shutil.copy2(set_file,out/"certified.set")
    for rel in CUSTOMER_DOCS:
        src=ROOT/rel
        if not src.exists(): raise SystemExit(f"ERROR: missing customer document: {rel}")
        dest=out/src.name
        shutil.copy2(src,dest)
    shutil.copy2(ROOT/"RELEASE_TRUTH_DASHBOARD.md",out/"RELEASE_TRUTH_DASHBOARD.md")
    shutil.copy2(ROOT/"release-truth-drift-validation.txt",out/"release-truth-drift-validation.txt")
    if sig:
        shutil.copy2(sig,out/sig.name)

    files=[]
    for p in sorted(x for x in out.rglob("*") if x.is_file()):
        files.append({"path":p.relative_to(out).as_posix(),"sha256":sha256(p),"size_bytes":p.stat().st_size})
    manifest={
        "schema_version":"gpt_ea_customer_package_v1",
        "release_validation_id":data.get("release_validation_id",""),
        "git_sha":data.get("build",{}).get("git_sha",""),
        "generated_at_utc":datetime.now(timezone.utc).isoformat(),
        "files":files,
        "external_signature_included":bool(sig),
    }
    mp=out/"PACKAGE_MANIFEST.json"
    mp.write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    (out/"PACKAGE_MANIFEST.sha256").write_text(sha256(mp)+"  PACKAGE_MANIFEST.json\n",encoding="utf-8")
    run([sys.executable,str(ROOT/"tools/scan_release_secrets.py"),str(out)])
    print("CUSTOMER RELEASE PACKAGE: PASS")
    print("OUTPUT="+str(out))
    return 0

if __name__=="__main__": raise SystemExit(main())

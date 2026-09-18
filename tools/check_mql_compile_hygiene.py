#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "GPT_EA.mq5"
FILEWRITE_MAX_VALUES = 63  # MQL5: values after the file handle

errors: list[str] = []
notes: list[str] = []

if not MAIN.exists():
    print("MQL COMPILE HYGIENE: FAILED")
    print("ERROR: GPT_EA.mq5 not found")
    raise SystemExit(1)

source = MAIN.read_text(encoding="utf-8", errors="replace")
lines = source.splitlines()


def iter_calls(name: str):
    token = name + "("
    pos = 0
    while True:
        start = source.find(token, pos)
        if start < 0:
            return
        i = start + len(token)
        depth = 1
        args = 1
        in_string = False
        escaped = False
        while i < len(source) and depth > 0:
            ch = source[i]
            if in_string:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == '"':
                    in_string = False
            else:
                if ch == '"':
                    in_string = True
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                elif ch == "," and depth == 1:
                    args += 1
            i += 1
        line = source.count("\n", 0, start) + 1
        yield line, args
        pos = max(i, start + len(token))


filewrite_calls = list(iter_calls("FileWrite"))
max_total_args = max((args for _, args in filewrite_calls), default=0)
for line, total_args in filewrite_calls:
    written_values = max(0, total_args - 1)
    if written_values > FILEWRITE_MAX_VALUES:
        errors.append(
            f"line {line}: FileWrite writes {written_values} values; MQL5 limit is {FILEWRITE_MAX_VALUES}"
        )

# Compiler-sensitive trade API returns must never be discarded.
for api in ("OrderCalcMargin", "OrderCheck", "OrderSend", "OrderSendAsync"):
    for line_no, _ in iter_calls(api):
        text = lines[line_no - 1].strip()
        checked = (
            re.search(rf"\b(if|while)\s*\([^\n]*!?\s*{api}\s*\(", text) is not None
            or re.search(rf"\b(bool|int|uint|long)\s+\w+\s*=\s*{api}\s*\(", text) is not None
            or re.search(rf"\b\w+\s*=\s*{api}\s*\(", text) is not None
            or re.search(rf"\breturn\s+{api}\s*\(", text) is not None
        )
        if not checked:
            errors.append(f"line {line_no}: return value of {api} appears unchecked: {text}")

# Preserve the explicit cast that removes MetaEditor's long -> datetime warning.
server_fn = re.search(
    r"datetime\s+ServerToUTC\s*\([^)]*\)\s*\{(?P<body>.*?)\n\}",
    source,
    re.S,
)
if not server_fn:
    errors.append("ServerToUTC function not found")
else:
    body = server_fn.group("body")
    if "long off=" not in body:
        errors.append("ServerToUTC no longer records the server/GMT offset as long")
    if "return (datetime)(serverTime-off);" not in body.replace(" ", ""):
        compact = re.sub(r"\s+", "", body)
        if "return(datetime)(serverTime-off);" not in compact:
            errors.append("ServerToUTC must explicitly cast serverTime-off to datetime")

# The release snapshot intentionally uses FileWriteString so it is not constrained
# by FileWrite's 63-value limit.
snapshot = re.search(
    r"void\s+WriteReleaseEvidenceSnapshot\s*\(\)\s*\{(?P<body>.*?)\n\}",
    source,
    re.S,
)
if not snapshot:
    errors.append("WriteReleaseEvidenceSnapshot function not found")
else:
    body = snapshot.group("body")
    if "FileWrite(" in body:
        errors.append("WriteReleaseEvidenceSnapshot must not use variadic FileWrite")
    if "FileWriteString(" not in body:
        errors.append("WriteReleaseEvidenceSnapshot must use FileWriteString")

notes.append(f"FILEWRITE_CALLS={len(filewrite_calls)}")
notes.append(f"FILEWRITE_MAX_TOTAL_ARGS={max_total_args}")
notes.append(f"FILEWRITE_MAX_WRITTEN_VALUES={max(0, max_total_args - 1)}")
notes.append(f"FILEWRITE_LIMIT={FILEWRITE_MAX_VALUES}")

if errors:
    print("MQL COMPILE HYGIENE: FAILED")
    for error in errors:
        print("ERROR:", error)
    for note in notes:
        print(note)
    sys.exit(1)

print("MQL COMPILE HYGIENE: PASS")
for note in notes:
    print(note)

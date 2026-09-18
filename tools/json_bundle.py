from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_PATH = ROOT / "GPT_EA_DATA.json"
MATERIALIZED_DIR = ROOT / ".generated-json"
_cache: dict[str, Any] | None = None


def _documents() -> dict[str, Any]:
    global _cache
    if _cache is None:
        payload = json.loads(BUNDLE_PATH.read_text(encoding="utf-8"))
        documents = payload.get("documents")
        if not isinstance(documents, dict):
            raise RuntimeError(f"{BUNDLE_PATH.name} is missing its documents object")
        _cache = documents
    return _cache


def has_json_document(name: str) -> bool:
    return name in _documents()


def load_json_document(name: str) -> Any:
    documents = _documents()
    if name not in documents:
        raise FileNotFoundError(f"JSON document {name!r} is not present in {BUNDLE_PATH.name}")
    return copy.deepcopy(documents[name])


def materialize_json_documents() -> Path:
    MATERIALIZED_DIR.mkdir(parents=True, exist_ok=True)
    for name, value in _documents().items():
        target = MATERIALIZED_DIR / name
        target.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return MATERIALIZED_DIR


def json_doc_path(name: str) -> Path:
    if not has_json_document(name):
        raise FileNotFoundError(f"JSON document {name!r} is not present in {BUNDLE_PATH.name}")
    materialize_json_documents()
    return MATERIALIZED_DIR / name

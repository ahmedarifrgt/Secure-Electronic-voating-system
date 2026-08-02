"""Standalone verification script - writes results incrementally."""
import ast
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent
backend_dir = root / "backend"
log = []

log.append("STEP: starting syntax check")
for p in sorted(backend_dir.rglob("*.py")):
    try:
        ast.parse(p.read_text(encoding="utf-8"))
    except SyntaxError as e:
        log.append(f"SYNTAX_ERROR {p.relative_to(root)}: line {e.lineno}: {e.msg}")

log.append("STEP: syntax check done")

# Write intermediate result
(root / "tmp_verify_result.json").write_text(
    json.dumps(log, indent=2), encoding="utf-8"
)
print("PHASE1_WRITTEN")


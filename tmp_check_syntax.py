import ast
import pathlib
import sys

root = pathlib.Path('backend')
errors = []
for p in root.rglob('*.py'):
    try:
        ast.parse(p.read_text(encoding='utf-8'))
    except SyntaxError as e:
        errors.append(f"{p}: line {e.lineno}: {e.msg}")

if errors:
    print("SYNTAX ERRORS FOUND:")
    for e in errors:
        print(" ", e)
    sys.exit(1)
else:
    print("All backend files parse OK.")


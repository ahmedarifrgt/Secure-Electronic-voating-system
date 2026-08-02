"""SQL injection guard.

Provides utilities to detect common SQLi payloads in user input before they
reach the database layer, and a helper to build safe parameterized filters.
"""
import re

_SQLI_PATTERNS = [
    re.compile(r"'\s*(or|and)\s*['\"]?\s*['\"]?1\s*=\s*1", re.IGNORECASE),
    re.compile(r"'\s*(or|and)\s*\w+\s*=\s*\w+", re.IGNORECASE),
    re.compile(r"--\s*$"),
    re.compile(r";\s*(drop|delete|insert|update|alter|truncate)\b", re.IGNORECASE),
    re.compile(r"(union\s+select|union\s+all\s+select)", re.IGNORECASE),
    re.compile(r"sleep\s*\(", re.IGNORECASE),
    re.compile(r"information_schema", re.IGNORECASE),
    re.compile(r"load_file\s*\(", re.IGNORECASE),
    re.compile(r"into\s+outfile", re.IGNORECASE),
    re.compile(r"0x[0-9a-fA-F]+", re.IGNORECASE),  # hex injection
]


def contains_sql_injection(value) -> bool:
    """Return True if the value looks like an SQLi payload."""
    if value is None:
        return False
    text = str(value)
    for pattern in _SQLI_PATTERNS:
        if pattern.search(text):
            return True
    return False


def assert_safe_input(values) -> list:
    """Validate a list/dict of values; return list of unsafe keys."""
    unsafe = []
    if isinstance(values, dict):
        items = values.items()
    elif isinstance(values, (list, tuple)):
        items = enumerate(values)
    else:
        items = [(0, values)]
    for key, val in items:
        if contains_sql_injection(val):
            unsafe.append(str(key))
    return unsafe


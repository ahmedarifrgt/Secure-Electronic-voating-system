"""XSS (Cross-Site Scripting) protection utilities."""
import re

# Patterns commonly used in XSS payloads
_XSS_PATTERNS = [
    re.compile(r"<\s*script", re.IGNORECASE),
    re.compile(r"<\s*/?\s*(iframe|object|embed|link|meta|style|img|svg)\b", re.IGNORECASE),
    re.compile(r"javascript\s*:", re.IGNORECASE),
    re.compile(r"on\w+\s*=", re.IGNORECASE),  # onerror=, onload=, etc.
    re.compile(r"document\.(cookie|location|body)", re.IGNORECASE),
    re.compile(r"eval\s*\(", re.IGNORECASE),
]


def contains_xss(value) -> bool:
    """Return True if the value contains XSS-like patterns."""
    if value is None:
        return False
    text = str(value)
    for pattern in _XSS_PATTERNS:
        if pattern.search(text):
            return True
    return False


def sanitize(value) -> str:
    """Strip or escape obvious XSS patterns."""
    if value is None:
        return ""
    text = str(value)
    # Escape the most dangerous characters
    text = text.replace(chr(38), "&amp;")
    text = text.replace(chr(60), "&lt;")
    text = text.replace(chr(62), "&gt;")
    text = text.replace(chr(34), "&quot;")
    text = text.replace(chr(39), "&#x27;")
    return text

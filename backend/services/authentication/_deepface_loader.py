"""Cached DeepFace loader.

The installed TensorFlow/Keras stack can deadlock when `from deepface import
DeepFace` runs inside a worker thread on Windows. All DeepFace imports in this
package go through the synchronous, cached helper below.

These helpers:
- never import deepface at module import time (so the backend always boots),
- import DeepFace once on the calling thread, where TensorFlow initializes
    correctly,
- return a sentinel when the installed backend raises an import error.
"""
from __future__ import annotations

import threading

_SENTINEL = object()
_loaded_result = None
_cache_lock = threading.Lock()


def _import_deepface():
    """Actually import DeepFace (meant to run in a worker thread)."""
    from deepface import DeepFace  # noqa: F401
    return DeepFace


def is_deepface_available() -> bool:
    """Return True if DeepFace can be imported without hanging."""
    return deepface() is not _SENTINEL


def deepface(timeout: float | None = None):
    """Return the DeepFace module object, or _SENTINEL if unimportable.

    TensorFlow/Keras initialization is not safe in a worker thread on Windows;
    importing it in a daemon thread can hang even when a direct import works.
    Import once, synchronously, and cache the result so all callers share the
    same initialized DeepFace module.

    ``timeout`` is retained for compatibility with existing callers, but cannot
    safely interrupt a Python import and is therefore intentionally ignored.
    """
    global _loaded_result
    with _cache_lock:
        if _loaded_result is not None:
            return _loaded_result

    try:
        loaded = _import_deepface()
    except Exception:
        loaded = _SENTINEL

    with _cache_lock:
        _loaded_result = loaded
    return _loaded_result


def reset_cache():
    """Clear the cached import result (mainly for tests)."""
    global _loaded_result
    with _cache_lock:
        _loaded_result = None

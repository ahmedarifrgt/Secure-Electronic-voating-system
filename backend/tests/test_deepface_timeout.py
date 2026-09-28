import time

from backend.services.authentication import face_embedding


def test_run_with_timeout_returns_none_for_slow_call():
    def slow_callable():
        time.sleep(0.2)
        return "done"

    result = face_embedding.run_with_timeout(slow_callable, timeout_seconds=0.05)

    assert result is None

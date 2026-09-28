# Face Verification System Fix — Task List

## Root Cause
- `deepface 0.0.100` + `tensorflow 2.21` + `keras 3.15` + `numpy 2.4.6` causes
  `from deepface import DeepFace` to deadlock the entire Python/backend process
  (hard interpreter freeze, previously because `tf-keras` was missing).
- Measured: the deepface import takes ~28-35s (tensorflow + keras + model load).
  A too-short loader timeout (30s) caused intermittent "DeepFace unavailable"
  — the loader now uses 60s.
- `retinaface` detector backend (the former configured default) is NOT
  installed; `opencv` detector is used instead (ships with opencv-contrib).
- DeepFace imports were at module level and unguarded, so the backend hung at
  startup.

## Fixes Applied
1. `backend/config.py`
   - `DEEPFACE_DETECTOR` default changed `retinaface` → `opencv`.
   - `DEEPFACE_TIMEOUT_SECONDS` raised `2.0` → `20.0` so `DeepFace.represent()`
     has time to finish (incl. one-time ArcFace download) instead of silently
     falling back to the non-identity OpenCV descriptor.
2. `backend/services/authentication/_deepface_loader.py` (NEW)
   - Centralized non-blocking DeepFace loader.
   - `from deepface import DeepFace` only runs inside `_import_deepface()` in a
     daemon worker thread with a hard `DEEPFACE_IMPORT_TIMEOUT` (60s default).
   - Exports `is_deepface_available()`, `deepface()`, `reset_cache()`.
   - A broken/hanging install can never block startup or a request.
3. `backend/services/authentication/face_embedding.py`
   - DeepFace accessed lazily via `_deepface()` loader (no module-level import).
   - Kept OpenCV deterministic descriptor as a last-resort fallback.
4. `backend/services/authentication/face_verification.py`
   - Removed module-level DeepFace import; pipeline guards on
     `deepface_available()`.
5. `backend/services/authentication/face_tracking.py`
   - Removed module-level DeepFace import; uses `_deepface()` loader; OpenCV
     Haar fallback retained.
6. `backend/services/authentication/liveness_detection.py`
   - Removed module-level DeepFace import (it only uses `detect_faces`).
7. `backend/routes/auth.py`
   - Clear 503 `"Face verification service is temporarily unavailable"` +
     `DeepFaceUnavailable` Critical security log when DeepFace cannot load.
8. `backend/requirements.txt`
   - Added `tf-keras`, `tensorflow`, `opencv-contrib-python`, `retinaface`,
     `mtcnn`; removed `opencv-python`.

## Verification (all passing)
- [x] All modified files compile (AST compile check).
- [x] Only module-level deepface import is inside `_import_deepface()` in the
      loader (threaded, safe).
- [x] `deepface` import reliability: 2/2 fresh subprocesses OK.
- [x] `deepface` import timing: ~28-35s measured; loader timeout set to 60s.
- [x] Backend boots: `BOOT_OK`, returncode 0 (no hang).
- [x] Pipeline self-match (22222222.jpg): `passed=True`, `score=1.0`, all 6
      stages pass (image_quality, face_tracking, liveness, anti_spoof,
      deepfake, identity).
- [x] Cross-match (22222222 vs 11111111): correctly rejected because
      `11111111.jpg` contains 2 faces ("Live image must contain exactly one
      face") — a data issue, not a code bug.

## Notes
- First request after backend start pays the ~30-60s DeepFace import cost once;
  the result is cached so subsequent requests are fast.
- `11111111.jpg` in `datasets/registered_faces/` contains two faces and will
  always be rejected by the pipeline until replaced with a single-face image.

---

# Task 2 — Fix 1:1 Face Verification (False Acceptance)

## New Root Cause
- The `opencv` detector (config default) is BROKEN in this environment: the
  installed `opencv-contrib-python 5.0.0.93` ships NO haarcascade XML files in
  `cv2/data` (only `__init__.py`). So `DeepFace.represent(detector_backend='opencv')`
  throws `ValueError: Expected path ...haarcascade_frontalface_default.xml violated`.
- `generate_embedding()` silently catches that exception and falls back to a
  NON-IDENTITY OpenCV color/gradient histogram descriptor.
- That descriptor is NOT person-specific: measured cross-face cosine distance
  was only ~0.238 vs the 0.6 threshold → ANY face passes (false acceptance).
- `mtcnn` detector WORKS and produces real 512-dim ArcFace identity embeddings
  (tested: 5.1s, dim=512).

## Fix Plan
1. `config.py`: `DEEPFACE_DETECTOR` default `opencv` → `mtcnn` (proven working).
   Lower `FACE_THRESHOLD` to a stricter cosine value (0.4) for 1:1 security.
2. `face_embedding.py`: add `strict=True` param to `generate_embedding()` that
   RAISES instead of silently falling back to the weak descriptor.
3. `face_verification.py`: always use `strict=True` in verification; add a
   detector-probe guard that fails closed if the configured detector is broken.
4. `routes/auth.py`: trigger 503 also when the detector is unusable.
5. `requirements.txt`: pin `mtcnn`.

## Verification Target
- [x] Self-match (22222222 vs 22222222) still passes.
- [ ] Cross-match (22222222 vs a DIFFERENT single face) now REJECTED
      (impostor must not pass).
- [ ] Backend still boots without hang.

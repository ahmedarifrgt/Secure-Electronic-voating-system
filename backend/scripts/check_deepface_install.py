"""Quick check for DeepFace availability inside the environment.

Usage: python backend/scripts/check_deepface_install.py
"""
import sys
try:
    import backend.services.authentication.face_verification as fv
    print("verify_face available:", hasattr(fv, 'verify_face'))
    print("verify_face_detailed available:", hasattr(fv, 'verify_face_detailed'))
    try:
        from deepface import DeepFace
        print('DeepFace import OK, version:', getattr(DeepFace, '__version__', 'unknown'))
    except Exception as e:
        print('DeepFace import failed:', e)
    print('HAS_DEEPFACE flag:', getattr(fv, 'HAS_DEEPFACE', False))
except Exception as e:
    print('Failed to import face_verification module:', e)
    sys.exit(2)

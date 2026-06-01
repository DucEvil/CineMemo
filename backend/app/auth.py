from typing import Dict

import firebase_admin
from firebase_admin import auth, credentials
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import get_firebase_project_id, get_firebase_service_account_path

security = HTTPBearer()


def _init_firebase() -> None:
    if firebase_admin._apps:
        return

    service_account_path = get_firebase_service_account_path()
    if not service_account_path:
        raise RuntimeError("FIREBASE_SERVICE_ACCOUNT is not set")

    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred, {"projectId": get_firebase_project_id()})


def verify_firebase_token(
    credentials_obj: HTTPAuthorizationCredentials = Depends(security),
) -> Dict:
    _init_firebase()
    try:
        decoded = auth.verify_id_token(credentials_obj.credentials)
    except Exception as exc:  # noqa: BLE001 - surface to client as 401
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase token",
        ) from exc

    return decoded

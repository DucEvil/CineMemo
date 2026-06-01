from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth import verify_firebase_token
from app.config import get_cors_origins

app = FastAPI(title="Movie Ticket API")

origins = get_cors_origins()
if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/me")
def get_me(user=Depends(verify_firebase_token)):
    return {
        "uid": user.get("uid"),
        "email": user.get("email"),
        "name": user.get("name"),
    }

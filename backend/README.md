# FastAPI backend for Cloud Run + Cloud SQL

## Local dev (optional)
1. Create a Firebase service account JSON and save it to `backend/secrets/firebase-service-account.json`.
2. Copy `.env.example` to `.env` and update values.
3. Run:

```
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```

## Deploy outline
- Build and deploy the container to Cloud Run.
- Create Cloud SQL (MySQL) and connect via Unix socket using Cloud Run settings.
- Store DB credentials and Firebase service account file as secrets.

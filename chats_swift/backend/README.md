# Chats Backend

FastAPI service that complements the SwiftUI client by handling offline message notifications and any future privileged server-side logic. The API listens on **port 8080** by default.

## Setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Copy `.env.sample` to `.env` (or provide environment variables directly) and fill in your Supabase credentials:

```ini
CHAT_SUPABASE_URL=https://your-project.supabase.co
CHAT_SUPABASE_SERVICE_KEY=your-service-role-key
CHAT_BACKEND_PORT=8080
```

## Run

```bash
uvicorn app.main:app --reload --port 8080
```

## API

- `POST /notify/offline-message`
  - Body: `{ "chat_id": "...", "recipient_ids": ["uuid"], "preview": "text" }`
  - Persists notification rows to `message_notifications` table and (stub) triggers downstream push delivery.
- `GET /health` simple readiness probe.

Extend `NotificationService` to plug in APNs/FCM as needed.

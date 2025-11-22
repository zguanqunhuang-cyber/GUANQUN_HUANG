# OpenIM Bridge Backend (Python)

Lightweight FastAPI service that turns Supabase-authenticated iOS requests into OpenIM REST
calls. Keeps the iOS demo simple while hiding the OpenIM admin secret.

## Features

- `POST /api/v1/token`: exchange Supabase (or debug) identity for OpenIM login token.
- `POST /api/v1/friend/request`: send friend requests between iOS users.
- `POST /api/v1/friend/accept`: accept or reject friend requests.
- `POST /api/v1/message/send`: simple single-chat text message relay for testing.
- `GET /healthz`: readiness probe.

## Configuration

Create a `.env` file (see `.env.example`) or export environment variables:

```env
OPENIM_BASE_URL=https://api.guanqunhuang.com
OPENIM_SECRET=openIM123
OPENIM_WS_URL=wss://api.guanqunhuang.com/msg_gateway
SUPABASE_JWT_SECRET= # optional, if set Authorization header is required
```

Additional knobs (with defaults) include:

| Variable | Default | Description |
| --- | --- | --- |
| `REQUEST_TIMEOUT_SECONDS` | `10` | HTTP timeout when calling OpenIM |
| `DEFAULT_PLATFORM_ID` | `1` | Platform ID for `/auth/user_token` |
| `LISTEN_HOST` / `LISTEN_PORT` | `0.0.0.0` / `8080` | Server bind address |

When `SUPABASE_JWT_SECRET` is unset you can pass `X-Debug-User: ios01` to impersonate a user.

## Install & Run

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Use `--reload` during development.

## Example Requests

```bash
# issue an OpenIM token for ios01 (debug mode)
curl -s http://localhost:8080/api/v1/token \
  -H 'Content-Type: application/json' \
  -H 'X-Debug-User: ios01' \
  -d '{}'

# send a friend request ios01 -> ios02
curl -s http://localhost:8080/api/v1/friend/request \
  -H 'Content-Type: application/json' \
  -H 'X-Debug-User: ios01' \
  -d '{"toUserID":"ios02","reqMsg":"hi!"}'

# accept as ios02
curl -s http://localhost:8080/api/v1/friend/accept \
  -H 'Content-Type: application/json' \
  -H 'X-Debug-User: ios02' \
  -d '{"fromUserID":"ios01","accept":true}'

# send a message
curl -s http://localhost:8080/api/v1/message/send \
  -H 'Content-Type: application/json' \
  -H 'X-Debug-User: ios01' \
  -d '{"toUserID":"ios02","text":"hello from bridge"}'
```

Point the iOS demo’s business/login endpoints to `http://<bridge-host>:8080` while keeping
`sdkAPIAddr`/`sdkWSAddr` directed at `https://api.guanqunhuang.com` and
`wss://api.guanqunhuang.com/msg_gateway`. The app will call this backend for account actions,
receive valid OpenIM tokens, and continue chatting via the official SDK.

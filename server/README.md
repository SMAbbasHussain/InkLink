Node WebSocket Server (InkLink)
=================================

This folder contains a lightweight Node.js WebSocket server used to relay CRDT updates between users, persist updates to Firestore, and store offline updates in Redis with a 7-day TTL.

Quick start (local):

```bash
cd server
cp .env.example .env
# set REDIS_URL and optionally GOOGLE_APPLICATION_CREDENTIALS or service-account.json
npm ci
npm start
```

Environment variables (see `.env.example`):
- `PORT` - port to run the server on (default 3000)
- `REDIS_URL` - redis connection string
- `GOOGLE_APPLICATION_CREDENTIALS` - optional path to service-account.json for Firebase Admin

Endpoints & Socket events:
- `watch_board` (client -> server): join a board room
- `leave_board` (client -> server): leave a board room
- `crdt_update` (client -> server): send a CRDT update (server broadcasts and writes to Firestore)
- `sync_offline` (client -> server): request queued updates for a given board; server replies with queued updates or `fallback_required` if TTL expired

Deployment notes:
- Use a host that supports long-lived WebSocket connections (Render, Railway, Heroku with websockets enabled, or Cloud Run with sticky session support).
- Provision a managed Redis and set `REDIS_URL` in your deployment environment variables.


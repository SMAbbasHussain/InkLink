# Node.js WebSocket & Media Token Server (`server/`)

The InkLink backend server is a high-performance Node.js service responsible for real-time WebSocket communication, CRDT update relaying, canvas cursor broadcasting, server-side Agora token minting (Chat & Voice RTC), and Redis-backed state persistence.

---

## Key Responsibilities

1. **Real-time Canvas Collaboration:** Relays Yjs CRDT binary updates and transient preview updates (drag coordinates, cursor states) between clients connected to the same board room.
2. **Offline Catch-Up Buffer:** Buffers board updates in Redis with a 7-day TTL so reconnecting clients can quickly fast-forward their board state.
3. **Board Chat Engine:** Manages board-scoped chat rooms, delivers live messages, and retains chat history in Redis with a 90-day retention window.
4. **Voice Room Signaling:** Relays speaking indicators and participant states for Agora RTC audio calls.
5. **Secure Agora Token Generation:**
   - Mints per-user Agora Chat tokens using `ChatTokenBuilder` via authenticated REST endpoints.
   - Generates RTC tokens using `RtcTokenBuilder` for board voice channels (`board_<boardId>`).

---

## Directory & File Overview

```text
server/
├── src/
│   └── index.js         # Core application: Express HTTP endpoints + Socket.IO handlers
├── .env.example         # Template for environment configuration
├── package.json         # Node.js dependencies & scripts
└── service-account.json # (Optional) Local Firebase Admin credentials
```

---

## HTTP REST Endpoints

All endpoints authenticate requests using a Firebase Auth ID token passed in the `Authorization: Bearer <token>` header.

### 1. Health Check
- **`GET /health`**
  - **Description:** Verifies server responsiveness and uptime.
  - **Response:** `200 OK` `{ "status": "ok", "time": "..." }`

### 2. Agora Chat Token
- **`POST /api/agora/chat/token`**
  - **Description:** Mints or retrieves a cached Agora Chat user token for the authenticated caller.
  - **Caching:** Tokens are cached in Redis under `agora_chat:token:<sanitized_uid>` with a TTL matched to token expiration.
  - **Response:**
    ```json
    {
      "agoraUsername": "user_uid_sanitized",
      "appKey": "org#app",
      "appId": "agora_app_id",
      "token": "token_string",
      "expiresAt": 1740000000000
    }
    ```

### 3. Agora RTC Voice Token
- **`POST /api/agora/rtc/token`**
  - **Description:** Validates caller access to the board and mints a 1-hour Agora RTC token for channel `board_<boardId>`.
  - **Body:** `{ "boardId": "string" }`
  - **Response:**
    ```json
    {
      "appId": "agora_app_id",
      "token": "rtc_token_string",
      "channelName": "board_<boardId>",
      "privilegeExpiredTs": 1740003600
    }
    ```

---

## WebSocket Events (Socket.IO)

Clients connect using `auth: { token: "<firebase_id_token>" }`. Connection origin is strictly checked against configured CORS origins.

| Event Name | Direction | Payload | Description |
| :--- | :--- | :--- | :--- |
| **`watch_board`** | Client $\rightarrow$ Server | `boardId: string` | Joins the caller to room `board:<boardId>`. |
| **`leave_board`** | Client $\rightarrow$ Server | `boardId: string` | Leaves the board room. |
| **`crdt_update`** | Client $\rightarrow$ Server | `{ boardId, update, version }` | Broadcasts update to all other room members, buffers to Redis, and queues a batch write to Firestore. |
| **`crdt_preview`** | Client $\rightarrow$ Server | `{ boardId, preview }` | Low-latency volatile broadcast for live dragging and pointer positions (not persisted). |
| **`sync_offline`** | Client $\rightarrow$ Server | `{ boardId, clientVersion }` | Requests missed updates from Redis queue since `clientVersion`. |
| **`board_chat_message`** | Client $\rightarrow$ Server | `{ boardId, text, senderName, ... }` | Broadcasts message to room and pushes to Redis chat history list. |
| **`get_board_chat_history`**| Client $\rightarrow$ Server | `{ boardId, limit }` | Returns recent board chat messages from Redis history. |
| **`join_voice_call`** | Client $\rightarrow$ Server | `{ boardId }` | Registers user in the active voice participants map and broadcasts updated list. |
| **`leave_voice_call`** | Client $\rightarrow$ Server | `{ boardId }` | Removes user from the voice participants map and broadcasts updated list. |
| **`voice_speaking_state`** | Client $\rightarrow$ Server | `{ boardId, isSpeaking }` | Broadcasts speaking pulse animation state to participants. |
| **`get_voice_participants`**| Client $\rightarrow$ Server | `{ boardId }` | Emits the current list of users active in the board voice call. |

---

## Environment Configuration

Configure the following variables in `server/.env`:

```env
# Server Port & CORS (setting CORS_ORIGIN replaces the default origin allowlist;
# include every deployed web client origin so HTTP and Socket.IO checks pass)
PORT=3000
CORS_ORIGIN=http://localhost:3000,https://inklink.web.app,https://inklink.app

# Redis Connection (Required for offline queue & board chat)
REDIS_URL=redis://127.0.0.1:6379

# Firebase Admin Credentials (Provide ONE of the following)
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
# FIREBASE_SERVICE_ACCOUNT_BASE64=
# GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
# SERVICE_ACCOUNT_PATH=./service-account.json

# Agora RTC Voice Configuration
AGORA_APP_ID=your_agora_app_id
AGORA_APP_CERTIFICATE=your_agora_app_certificate

# Agora Chat REST API Configuration
AGORA_CHAT_REST_BASE=https://a61.chat.agora.io
AGORA_CHAT_ORG_NAME=your_org_name
AGORA_CHAT_APP_NAME=your_app_name
AGORA_CHAT_REST_CLIENT_ID=your_client_id
AGORA_CHAT_REST_CLIENT_SECRET=your_client_secret
AGORA_CHAT_TOKEN_EXPIRY_HOURS=24

# Redis Retention Policies
BOARD_CHAT_HISTORY_TTL_DAYS=90
```

---

## Setup & Running

```bash
# 1. Navigate to directory
cd server

# 2. Install dependencies
npm install

# 3. Start server
npm start

# For development with auto-reload:
npm run dev
```

---

## Deployment Recommendations

- **WebSocket Support:** Deploy on platforms with native WebSocket support (e.g. Render, Railway, AWS ECS, or Google Cloud Run with session affinity and HTTP/2/WebSockets enabled).
- **Persistent Redis:** Use managed Redis (e.g. Redis Cloud, Upstash, or AWS ElastiCache) with append-only file (AOF) persistence enabled so board chat history and offline CRDT buffers survive server redeployments.

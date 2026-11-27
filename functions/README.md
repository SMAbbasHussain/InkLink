# InkLink Firebase Cloud Functions (`functions/`)

This directory houses the serverless backend for InkLink, implemented as modular Firebase Cloud Functions (v2 `onCall` callables). These functions handle privileged operations, profile media uploads, relationship workflows, workspace management, and board access governance.

---

## Architecture & Conventions

### Dynamic Function Loader
[`functions/index.js`](index.js) scans all files matching `src/**/*.js` (excluding `src/utils/**`) and dynamically exports them as Cloud Functions.

- **Naming Convention:** Filenames are converted to `camelCase` function triggers.
  - `src/boards/delete_board.js` $\rightarrow$ `deleteBoard`
  - `src/workspaces/create_workspace.js` $\rightarrow$ `createWorkspace`
  - `src/friends/accept_friend_request.js` $\rightarrow$ `acceptFriendRequest`
- **Module Contract:** Each handler file must export a single async function:
  ```javascript
  module.exports = async (request) => {
    // request.auth.uid contains caller identity
    // request.data contains input payload
    return { status: 'success' };
  };
  ```
- **Execution Defaults:** Standard functions run in `us-central1` (or `FIREBASE_REGION`) with a 540-second timeout and Cloudflare R2 secrets bound. AI functions (`src/ai/*.js`) run with a 120-second timeout, `1GiB` memory (for `sharp` image processing), and additional Cloudflare Workers AI secrets (`CLOUDFLARE_AI_API_TOKEN`, `CLOUDFLARE_AI_ACCOUNT_ID`).
- **Utility Exclusion:** Files under `src/utils/**` and files ending in `*_utils.js` are excluded from dynamic export.

---

## Functional Domain Breakdown

```text
functions/
├── index.js                     # Dynamic function loader & runtime export
├── package.json                 # Node 22 engine & dependencies
├── scripts/
│   └── serve_local_ai_images.js # Local dev server for AI image emulator testing
├── server/
│   └── firebase-admin.js        # Shared Firebase Admin initialization
├── test/
│   ├── ai/                      # Unit tests for AI utils, providers & local storage
│   └── workspaces/              # Unit tests for workspace invite flows
└── src/
    ├── ai/                      # AI image generation, editing & inpainting
    │   ├── ai_access_utils.js
    │   ├── ai_provider_utils.js
    │   ├── ai_request_utils.js
    │   ├── ai_storage_utils.js
    │   ├── ai_usage_utils.js
    │   ├── edit_ai_image.js
    │   ├── generate_ai_image.js
    │   └── inpaint_ai_image.js
    │
    ├── boards/                  # Board lifecycle, pause state, undo requests & permissions
    │   ├── delete_board.js
    │   ├── join_board_by_code.js
    │   ├── remove_board_member.js
    │   ├── request_board_access.js
    │   ├── resolve_undo_request.js
    │   ├── respond_to_board_access_request.js
    │   ├── set_board_paused.js
    │   ├── submit_undo_request.js
    │   ├── update_board_member_role.js
    │   └── update_board_settings.js
    │
    ├── friends/                 # Social graph & friend request management
    │   ├── accept_friend_request.js
    │   ├── block_user.js
    │   ├── cancel_friend_request.js
    │   ├── decline_friend_request.js
    │   ├── relationship_utils.js
    │   ├── report_user.js
    │   ├── send_friend_request.js
    │   ├── unblock_user.js
    │   └── unfriend_user.js
    │
    ├── invitations/             # Board invitations
    │   ├── accept_board_invite.js
    │   └── decline_board_invite.js
    │
    ├── notifications/           # Push notification triggers & mentions
    │   ├── send_board_invite.js
    │   └── send_comment_mention.js
    │
    ├── profile/                 # Profile management & media uploads
    │   ├── delete_user_account.js
    │   └── upload_profile_photo.js
    │
    ├── workspaces/              # Team workspaces & organization
    │   ├── accept_workspace_invite.js
    │   ├── add_board_to_workspace.js
    │   ├── create_workspace.js
    │   ├── create_workspace_board.js
    │   ├── delete_workspace.js
    │   ├── invite_to_workspace.js
    │   ├── join_workspace.js
    │   ├── leave_workspace.js
    │   ├── reject_workspace_invite.js
    │   ├── remove_board_from_workspace.js
    │   ├── set_workspace_board_visibility.js
    │   └── update_workspace.js
    │
    └── utils/                   # Shared validation, constants, and logging
        ├── firestore_paths.js   # Centralized Firestore collection paths
        ├── logger.js            # Structured JSON logger
        ├── notification_sender.js
        ├── r2_history.js        # R2 board history cleanup helpers
        ├── redis.js             # Upstash / ioredis cache sync helpers
        └── validation.js        # Input sanitization & boundary validation
```

---

## Callable API Catalog

### 1. Workspaces
- **`createWorkspace`**: Initializes a workspace with the caller as Owner.
- **`inviteToWorkspace`**: Issues an invite to a user email/UID with specific permissions.
- **`acceptWorkspaceInvite` / `rejectWorkspaceInvite`**: Handles recipient decision on workspace invites.
- **`joinWorkspace`**: Allows joining an open or code-protected workspace.
- **`leaveWorkspace`**: Leaves membership; enforces owner transfer if last owner.
- **`deleteWorkspace`**: Cascades workspace deletion and decouples child boards.
- **`addBoardToWorkspace` / `removeBoardFromWorkspace`**: Associates or detaches boards.
- **`setWorkspaceBoardVisibility`**: Toggles whether a board is visible to all workspace members.

### 2. Boards & Access Control
- **`deleteBoard`**: Atomically removes board metadata, canvas states, comments, and R2 history archives.
- **`joinBoardByCode`**: Resolves share codes and adds user as a board member.
- **`requestBoardAccess`**: Creates an access request when a user visits a private deep link.
- **`respondToBoardAccessRequest`**: Approves or denies pending access requests.
- **`updateBoardMemberRole`**: Adjusts collaborator permissions (Editor/Viewer).
- **`updateBoardSettings`**: Updates board metadata and collaboration settings.
- **`setBoardPaused`**: Pauses or resumes editing on a board (owner control).
- **`submitUndoRequest` / `resolveUndoRequest`**: Allows members to submit area/state undo requests and owners to approve or reject them.
- **`removeBoardMember`**: Revokes access for a collaborator.

### 3. AI Image Generation & Editing (`src/ai/`)
- **`generateAiImage`**: Generates an image from a text prompt (`1:1`, `16:9`, `9:16`) via Cloudflare Workers AI (`flux-2-klein-4b` / `flux-1-schnell`), normalizes to PNG with `sharp`, stores in R2, and enforces per-user daily quotas.
- **`editAiImage`**: Applies prompt-guided image-to-image edits on an existing canvas image.
- **`inpaintAiImage`**: Performs masked inpainting on a selected region of an image.

### 3. Social & Friends
- **`sendFriendRequest` / `cancelFriendRequest`**: Manages outgoing friend requests.
- **`acceptFriendRequest` / `declineFriendRequest`**: Manages incoming friend requests.
- **`unfriendUser`**: Mutually severs friend relationship.
- **`blockUser` / `unblockUser`**: Restricts social visibility and messaging.
- **`reportUser`**: Logs user conduct reports for moderation.

### 4. Profiles & Notifications
- **`uploadProfilePhoto`**: Validates image chunks and persists avatars to Cloudflare R2, returning public CDN URLs.
- **`deleteUserAccount`**: Full GDPR-compliant purge of user profile, owned assets, and credentials.
- **`sendCommentMention`**: Sends FCM push notifications to users tagged with `@username` in board pins.

---

## Configuration & Secrets

### Environment Variables
- `FIREBASE_REGION`: Regional deployment target (defaults to `us-central1`).
- `DEBUG`: Set to `'true'` to output verbose debug logging.

### Cloudflare R2 & Workers AI Secrets
Required for avatar/AI media storage, board history cleanup, and AI image generation:
- `CLOUDFLARE_R2_ACCESS_KEY`
- `CLOUDFLARE_R2_SECRET_KEY`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_R2_BUCKET`
- `CLOUDFLARE_R2_PUBLIC_URL`
- `CLOUDFLARE_R2_HISTORY_BUCKET`
- `CLOUDFLARE_AI_API_TOKEN` (AI functions only)
- `CLOUDFLARE_AI_ACCOUNT_ID` (AI functions only)

Set secrets via Firebase CLI:
```bash
firebase functions:secrets:set CLOUDFLARE_R2_ACCESS_KEY
firebase functions:secrets:set CLOUDFLARE_R2_SECRET_KEY
firebase functions:secrets:set CLOUDFLARE_ACCOUNT_ID
firebase functions:secrets:set CLOUDFLARE_R2_BUCKET
firebase functions:secrets:set CLOUDFLARE_R2_PUBLIC_URL
firebase functions:secrets:set CLOUDFLARE_R2_HISTORY_BUCKET
firebase functions:secrets:set CLOUDFLARE_AI_API_TOKEN
firebase functions:secrets:set CLOUDFLARE_AI_ACCOUNT_ID
```

---

## Local Development, Testing & Deployment

### Run Unit Tests
```bash
cd functions
npm install
npm test
```

### Run Functions Emulator
```bash
cd functions
npm install
npm run serve
```

### Deploy to Firebase
```bash
# Deploy all functions
npm run deploy

# Deploy a single function
firebase deploy --only functions:uploadProfilePhoto
firebase deploy --only functions:createWorkspace
```

---

## Data Consistency Rules

- **Shared Constants:** Always keep [`src/utils/firestore_paths.js`](src/utils/firestore_paths.js) aligned with the Flutter client's [`lib/core/constants/firestore_paths.dart`](../lib/core/constants/firestore_paths.dart).
- **Atomic Transactions:** Multi-document operations (such as friendship creation, workspace joins, and board deletions) must always execute inside Firestore transactions.

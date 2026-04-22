# InkLink Cloud Functions

This directory contains Firebase callable backend functions used by the InkLink Flutter app.

## Runtime and Scripts

- Runtime: Node.js 22 (defined in package.json)
- Main entry: index.js
- Scripts:
  - npm run serve -> Firebase emulator (functions only)
  - npm run shell -> Firebase functions shell
  - npm run deploy -> deploy all functions
  - npm run logs -> fetch Cloud Functions logs

## Directory Layout

```text
functions/
|-- index.js
|-- package.json
|-- server/
|   `-- firebase-admin.js
`-- src/
    |-- boards/
    |-- friends/
    |-- invitations/
    |-- notifications/
    |-- profile/
    `-- utils/
```

Main functional areas currently present:

- boards: board lifecycle operations (for example board deletion).
- friends: send/cancel/accept/decline requests, block/unblock, unfriend, report.
- invitations: accept/decline board invites.
- notifications: send notification and send board invite notification.
- profile: upload profile photo to Cloudflare R2.
- utils: validation, path constants, structured logger, notification helpers.

## Function Loader Convention

index.js dynamically loads handlers from src/**/*.js except src/utils/**.

Important conventions:

- Every function module must export a single handler:
  - module.exports = async (request) => { ... }
- Export name is generated from filename and converted to camelCase.
  - Example: src/friends/accept_friend_request.js -> acceptFriendRequest
  - Example: src/invitations/accept_board_invite.js -> acceptBoardInvite
- Each exported function is wrapped in firebase-functions/v2 onCall with:
  - region from FIREBASE_REGION (default us-central1)
  - timeoutSeconds 540
  - Cloudflare R2 secrets list for runtime injection

If a module does not export a function, it is skipped.

## Setup

### Prerequisites

- Node.js 22+
- Firebase CLI installed and authenticated
- Access to the Firebase project

### Install

```bash
npm install
```

### Local run

```bash
npm run serve
```

### Deploy

```bash
npm run deploy
```

Deploying one function (example):

```bash
firebase deploy --only functions:acceptFriendRequest
```

## Configuration

Environment and runtime settings used by current code:

- FIREBASE_REGION (optional, defaults to us-central1)
- DEBUG=true enables verbose logger output

Cloudflare R2 secrets expected by profile upload flow:

- CLOUDFLARE_R2_ACCESS_KEY
- CLOUDFLARE_R2_SECRET_KEY
- CLOUDFLARE_ACCOUNT_ID
- CLOUDFLARE_R2_BUCKET
- CLOUDFLARE_R2_PUBLIC_URL

The profile upload function validates these values at runtime and fails fast if missing.

## Security and Data Consistency

- Functions expect authenticated callers (request.auth.uid).
- Input validation is centralized in src/utils/validation.js and reused across handlers.
- Firestore collection/field constants are centralized in src/utils/firestore_paths.js.
- Keep Firestore path constants in sync with Flutter:
  - ../lib/core/constants/firestore_paths.dart
  - src/utils/firestore_paths.js

## Development Notes

- Prefer transactions for multi-document mutations.
- Keep handlers thin: validate input, enforce auth/permissions, run business operation, return plain objects.
- Use src/utils/logger.js for structured logs (info/warn/error/debug).

## Troubleshooting

- Function missing after startup:
  - Check emulator logs for loader warnings/errors.
  - Confirm module.exports is a function.
- Callable name mismatch from Flutter:
  - Confirm filename-to-camelCase mapping used by index.js.
- Permission or auth errors:
  - Verify caller is authenticated and Firestore rules align with function behavior.

## 📖 Best Practices

1. **Always validate input** - Use the validation utilities
2. **Use transactions** - Ensure atomicity for multi-document operations
3. **Log appropriately** - Use structured logging for monitoring
4. **Handle errors gracefully** - Return meaningful HttpsError messages
5. **Test before deploying** - Use the emulator locally
6. **Monitor in production** - Check Cloud Logging regularly

## 🔗 Related Documentation

- [Firebase Cloud Functions Docs](https://firebase.google.com/docs/functions)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/start)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

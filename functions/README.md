# Firebase Cloud Functions for InkLink

This directory contains the Cloud Functions that power the backend logic for the InkLink application.

## 📁 Structure

```
functions/
├── src/
│   ├── utils/
│   │   ├── validation.js      # Input validation utilities
│   │   ├── firestore_paths.js # Firestore constants (matches Flutter app)
│   │   └── logger.js          # Structured logging utilities
│   ├── friends/
│   │   ├── accept_friend_request.js  # Accept friend request function
│   │   ├── block_user.js             # Block a user and clear relationship state
│   │   ├── decline_friend_request.js # Decline friend request function
│   │   ├── report_user.js            # Submit a moderation report
│   │   ├── send_friend_request.js    # Send friend request function
│   │   ├── relationship_utils.js     # Shared relationship helpers
│   │   └── unfriend_user.js          # Remove an existing friendship
├── server/
│   └── firebase-admin.js      # Firebase Admin SDK initialization
├── index.js                   # Function loader and router
├── package.json              # Dependencies and configuration
└── .env.example              # Environment configuration template
```

## 🚀 Getting Started

### Prerequisites
- Node.js 20 LTS (as specified in `package.json`)
- Firebase CLI: `npm install -g firebase-tools`
- A Firebase project with Firestore enabled

### Installation

```bash
# Install dependencies
npm install

# Copy the environment template and configure if needed
cp .env.example .env.local
```

### Local Development

```bash
# Start Firebase emulators with functions
npm run serve

# Open Firebase functions shell for testing
npm run shell

# View function logs
npm run logs
```

### Deployment

```bash
# Deploy functions to Firebase
npm run deploy

# Deploy a specific function
firebase deploy --only functions:accept_friend_request
```

## 📋 Available Functions

### `accept_friend_request`

Accepts a pending friend request and creates a bidirectional friendship.

**Request Data:**
```typescript
{
  requestId: string  // Format: "uid1_uid2" (deterministic)
}
```

**Response:**
```typescript
{
  success: boolean,
  message: string
}
```

**Errors:**
- `unauthenticated`: User is not logged in
- `invalid-argument`: Invalid requestId format
- `not-found`: Request or user account not found
- `permission-denied`: User is not the recipient
- `internal`: Unexpected server error

**Features:**
- ✅ Atomic transaction (prevents race conditions)
- ✅ User existence validation
- ✅ Idempotency (safe to call multiple times)
- ✅ Comprehensive error handling
- ✅ Structured logging

### `decline_friend_request`

Declines a pending friend request by deleting it.

**Request Data:**
```typescript
{
  requestId: string  // Format: "uid1_uid2"
}
```

**Response:**
```typescript
{
  success: boolean,
  message: string
}
```

**Errors:**
- `unauthenticated`: User is not logged in
- `invalid-argument`: Invalid requestId format
- `not-found`: Request not found
- `permission-denied`: User is not the recipient
- `internal`: Unexpected server error

**Features:**
- ✅ Atomic transaction
- ✅ Permission verification
- ✅ Comprehensive error handling
- ✅ Structured logging

### `unfriend_user`

Removes a friendship from both users and clears any related pending request.

**Request Data:**
```typescript
{
  targetUid: string
}
```

**Response:**
```typescript
{
  success: boolean,
  message: string
}
```

### `block_user`

Blocks another user, removes any friendship or pending request state, and stores a block record.

**Request Data:**
```typescript
{
  targetUid: string,
  reason?: string
}
```

### `report_user`

Stores a moderation report for another user.

**Request Data:**
```typescript
{
  targetUid: string,
  reason?: string
}
```

## 🔧 Configuration

### Environment Variables

Create a `.env.local` file (or set in Firebase Cloud Functions):

```env
# Firebase Cloud Functions region
FIREBASE_REGION=us-central1

# Enable debug logging (true/false)
DEBUG=false
```

### Firebase Region

The default region is `us-central1`. To change it:

```bash
# Option 1: Set environment variable
export FIREBASE_REGION=europe-west1

# Option 2: Modify the region in index.js
const FIREBASE_REGION = process.env.FIREBASE_REGION || 'your-region';
```

## 🛡️ Security

### Firestore Rules

Ensure your Firestore security rules protect the `friend_requests` collection:

```javascript
// Allow only authenticated users to read their own requests
match /friend_requests/{requestId} {
  allow read: if request.auth.uid in [
    resource.data.fromUid, 
    resource.data.toUid
  ];
  // Creating requests is handled by client-side code
  allow delete: if false; // Only Cloud Functions can delete
}
```

### Authentication

All functions require Firebase Authentication. The `auth` context is automatically provided by Firebase SDK.

### Input Validation

All functions validate:
- Authentication status
- Request data completeness
- UID format and length
- User existence in Firestore
- Permission verification

## 📊 Monitoring

### Cloud Logging

View function logs in Firebase Console:
1. Go to Cloud Functions
2. Click on a function
3. View "Logs" tab

Or use the CLI:
```bash
npm run logs
```

### Debug Mode

Enable debug logging by setting `DEBUG=true` in `.env.local`:
```bash
DEBUG=true npm run serve
```

Debug logs will show:
- Function entry/exit
- Data validation steps
- Transaction details
- User information (UIDs)

## 🧪 Testing

### Test with Firebase Emulator

```bash
# Start emulator
npm run serve

# In another terminal, test the function
firebase functions:shell

# In the shell:
> accept_friend_request({requestId: "uid1_uid2"})
```

### Test with cURL

```bash
curl -X POST http://localhost:5001/your-project/us-central1/accept_friend_request \
  -H "Content-Type: application/json" \
  -d '{"data":{"requestId":"uid1_uid2"}}'
```

## 📚 Utilities

### validation.js

Utilities for validating Cloud Function inputs:

```javascript
const { validateUID, validateRequestId, validateDifferentUIDs } = require('./utils/validation');

validateUID(uid, 'userId');           // Validates UID format
validateRequestId(id);                // Validates request ID format
validateDifferentUIDs(uid1, uid2);    // Ensures UIDs are different
```

### firestore_paths.js

Constants matching the Flutter app's paths:

```javascript
const FirestorePaths = require('./utils/firestore_paths');

FirestorePaths.USERS              // 'users'
FirestorePaths.FRIEND_REQUESTS    // 'friend_requests'
FirestorePaths.FRIENDS_SUBCOLLECTION  // 'friends'
```

### logger.js

Structured logging that integrates with Cloud Logging:

```javascript
const logger = require('./utils/logger');

logger.info('Operation completed', { userId, action });
logger.warn('Unusual condition', { reason });
logger.error('Operation failed', error);
logger.debug('Debug info', { details }); // Only in DEBUG mode
```

## 🔄 Function Loading

The `index.js` file automatically loads all functions from `src/` directory:

- Files in `src/*.js` become top-level functions: `accept_friend_request`
- Files in `src/auth/*.js` become nested functions: `auth_login`
- Files in `src/utils/**/*.js` are ignored (utility files)

To add a new function:
1. Create `src/my_function.js`
2. Export an async handler: `module.exports = async (request) => {...}`
3. Restart the function loader - it will auto-detect

## 🐛 Troubleshooting

### Function not loading

Check `index.js` logs for errors:
```bash
npm run serve
# Look for "Error loading function file" messages
```

### Permission denied errors

Verify:
1. User is authenticated
2. User token is valid
3. Firestore doesn't have overly restrictive rules

### Timeout errors

If functions timeout:
1. Check Firestore query performance
2. Enable debug logging to see bottlenecks
3. Increase timeout in `index.js` (default: 540 seconds)

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

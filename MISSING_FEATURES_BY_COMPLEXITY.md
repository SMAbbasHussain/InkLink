# InkLink: Missing & Partial Features by Module (Sorted by Complexity)

**Generated:** October 10, 2026  
**Reference Document:** `Requirements.docx`  
**Purpose:** Actionable engineering backlog grouping all 51 missing (❌) and partial (⚠️) requirements by module, ordered by **ascending complexity (easiest/quickest wins first → most architecturally complex systems last)**.

---

## Master Complexity Level Reference

| Complexity Level | Score | Description | Typical Effort |
| :--- | :---: | :--- | :---: |
| **Level 1: Quick Fix / Minor Addition** | 🟢 1/5 | Simple UI validation, regex check, flag toggle, or minor parameter addition. | 1 – 3 hours |
| **Level 2: Standard UI / Service Addition** | 🟡 2/5 | Standard form/dialog, basic Firebase method call, simple model field + UI hook. | 4 – 8 hours |
| **Level 3: Moderate Feature / New Component** | 🟠 3/5 | New screen, compound model, Cloud Function endpoint, local DB schema addition. | 1 – 2 days |
| **Level 4: Advanced Engine / Multi-Layer Feature** | 🔴 4/5 | Canvas math/rendering engine changes, real-time WebSocket protocol additions, AI integration. | 3 – 5 days |
| **Level 5: Major Subsystem Architecture** | 🟣 5/5 | Full real-time subsystem (Voice WebRTC, complete Offline-first DM platform). | 1 – 2 weeks |

---

## Table of Modules

1. [Module 1: Authentication & Identity (FR01)](#module-1-authentication--identity-fr01)
2. [Module 2: User Profile & Preferences (FR02)](#module-2-user-profile--preferences-fr02)
3. [Module 3: Board Creation & Management (FR03)](#module-3-board-creation--management-fr03)
4. [Module 4: Canvas Tools & Visual Elements (FR05)](#module-4-canvas-tools--visual-elements-fr05)
5. [Module 5: Board Sharing & Access Control (FR07)](#module-5-board-sharing--access-control-fr07)
6. [Module 6: Notifications & Preferences (FR15)](#module-6-notifications--preferences-fr15)
7. [Module 7: Presence & Live Awareness (FR08)](#module-7-presence--live-awareness-fr08)
8. [Module 8: Board Export & File Sharing (FR11)](#module-8-board-export--file-sharing-fr11)
9. [Module 9: Public Board Access & Discovery (FR14)](#module-9-public-board-access--discovery-fr14)
10. [Module 10: AI-Assisted Object Generation & Limits (FR06 & FR16)](#module-10-ai-assisted-object-generation--limits-fr06--fr16)
11. [Module 11: In-App Communication & Audio (FR12)](#module-11-in-app-communication--audio-fr12)
12. [Module 12: Direct Messaging (DM) System (FR17)](#module-12-direct-messaging-dm-system-fr17)
13. [Cross-Module Global Backlog Summary](#cross-module-global-backlog-summary)

---

## Module 1: Authentication & Identity (FR01) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR01-04** | Enforce minimum password strength rules | ✅ **Implemented** | 🟢 **Level 1 (1/5)** | Enforced in [`helpers.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/utils/helpers.dart) requiring min 8 chars, uppercase, lowercase, digit, and symbol with clear error feedback in [`register_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/register_screen.dart). |
| **FR01-05** | Send email verification upon registration | ✅ **Implemented** | 🟢 **Level 1.5 (1.5/5)** | Dispatched automatically in [`auth_session_service.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/services/auth/auth_session_service.dart) via Firebase built-in email service upon `signUp()`. Users can also resend from [`email_verification_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/email_verification_screen.dart). |
| **FR01-07** | Reset forgotten passwords via email | ✅ **Implemented** | 🟢 **Level 1.5 (1.5/5)** | Connected "Forgot Password?" dialog in [`login_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/login_screen.dart) triggering `sendPasswordResetEmail()` via Firebase Auth in repository and `AuthBloc`. |
| **FR01-06** | Restrict login to verified users only | ✅ **Implemented** | 🟡 **Level 2 (2/5)** | Enforced in [`auth_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/bloc/auth_bloc.dart) on `LoginRequested`, `RegisterRequested`, and `AuthCheckRequested`. Routes unverified accounts to [`email_verification_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/email_verification_screen.dart) with interactive reload verification check and resend timer. |

---

## Module 2: User Profile & Preferences (FR02) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR02-04** | Validate profile photo format (PNG, JPEG, JPG) | ✅ **Implemented** | 🟢 **Level 1.5 (1.5/5)** | Strictly enforced in [`upload_profile_photo.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/profile/upload_profile_photo.js) and [`edit_profile_sheet.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/profile/view/widgets/edit_profile_sheet.dart) via file extension checks and magic byte header validation (`0xFF 0xD8 0xFF` for JPEG and `0x89 0x50 0x4E 0x47` for PNG). |
| **FR02-10** | Configure profile privacy settings | ✅ **Implemented** | 🟡 **Level 2 (2/5)** | Added `isProfilePublic`, `showOnlineStatus`, and `showEmail` to [`user_model.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/user_model.dart) and Firestore schema. Added interactive switch tiles in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart) wired to `SettingsBloc` and `ProfileService`. |
| **FR02-11**<br>**FR02-12** | Select & store preferred tags for content personalization | ✅ **Implemented** | 🟡 **Level 2 (2/5)** | Added `preferredTags: List<String>` to [`user_model.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/user_model.dart). Built an interactive tag picker with suggestions (`Art`, `Architecture`, `Brainstorming`, `Design`, `Education`, etc.) and custom tag entry in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart). |
| **FR02-05** | Update user preferences | ✅ **Implemented** | 🟡 **Level 2 (2/5)** | Extended [`settings_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/bloc/settings_bloc.dart) and [`profile_service.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/services/profile/profile_service.dart) to persist privacy preferences and preferred tags to Firestore for authenticated users. |
| **FR02-06**<br>**FR02-07** | Account deletion with associated user data removal | ✅ **Implemented** | 🟠 **Level 3 (3/5)** | 1. Built Cloud Function [`delete_user_account.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/profile/delete_user_account.js) cascade-purging user boards, Redis states, board memberships, reciprocal friendships, requests, notifications, Cloudflare R2 profile photo, Firestore user document, and Firebase Auth record.<br>2. Added "Delete Account" button with destructive confirmation modal in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart), wired to `AuthBloc` (`DeleteAccountRequested`), `AuthSessionService`, and `AuthRepository`. |

---

## Module 3: Board Creation & Management (FR03)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR03-13** | Validate board tags against predefined format | ⚠️ Partial | 🟢 **Level 1 (1/5)** | In [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart) and [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart), enforce tag length `<= 20`, lowercase alphanumeric chars and hyphens only (`RegExp(r'^[a-z0-9\-]+$')`). |
| **FR03-08** | Owners archive / unarchive boards | ❌ Missing | 🟡 **Level 2 (2/5)** | Add `isArchived: bool` field to [`board.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/board.dart) and Firestore. Add "Archive Board" option in board settings popup menu. Filter out archived boards from dashboard default view, adding an "Archived" tab or toggle. |
| **FR03-07** | Owners duplicate boards | ❌ Missing | 🟡 **Level 2.5 (2.5/5)** | Add `duplicateBoard(boardId)` in [`board_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/board/board_repository_impl.dart). Deep copy the board document, clone latest Firestore CRDT snapshot document to a new board document ID with title `"$title (Copy)"`. Add UI button in [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart). |
| **FR03-11** | Move boards between workspaces | ⚠️ Partial | 🟡 **Level 2.5 (2.5/5)** | Create an atomic "Move Board to Workspace" modal dialog in [`workspace_detail_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/workspaces/view/workspace_detail_screen.dart). Execute an atomic Firestore batch to remove from source workspace subcollection and insert into destination workspace. |

---

## Module 4: Canvas Tools & Visual Elements (FR05)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR05-16** | Capture images using device camera to canvas | ❌ Missing | 🟢 **Level 1 (1/5)** | In [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart#L325), provide a bottom sheet to let the user pick between `ImageSource.gallery` or `ImageSource.camera` with camera permission handler before pushing to `MediaEditorScreen`. |
| **FR05-04** | Predefined Arrow shape | ⚠️ Partial | 🟡 **Level 2 (2/5)** | Add `arrow` value to [`canvas_shape_type.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/canvas_shape_type.dart). In [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart), implement `_drawArrowShape(Canvas, Rect, Paint)` calculating shaft line and triangle arrowhead points. |
| **FR05-09** | Insert sticky notes | ❌ Missing | 🟠 **Level 3 (3/5)** | 1. Create `StickyNoteElement` extending [`CanvasElement`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/models/canvas_element.dart) with text, note color (yellow, cyan, lime, rose), size, and shadow.<br>2. Add Sticky Note tool icon to Tools/Shapes tray.<br>3. In [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart), paint rounded rectangle with drop-shadow and render wrapped multi-line text inside. |
| **FR05-13**<br>**FR05-14**<br>**FR05-15** | Connectors & Flowchart diagrams with dynamic link maintenance | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Define `ConnectorElement` with `startElementId`, `startAnchor`, `endElementId`, `endAnchor`, line style (straight, orthogonal, curved).<br>2. Add anchor snap points (top/bottom/left/right) when hovering shapes in connector mode.<br>3. In `CanvasBloc`, when an element is moved/scaled, dynamically update attached connector paths to preserve link topology in CRDT. |

---

## Module 5: Board Sharing & Access Control (FR07)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR07-05** | Revoke member access from board | ⚠️ Partial | 🟡 **Level 2 (2/5)** | In [`members_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/members_tray.dart), add a popup menu with "Revoke Access" for non-owners (visible only to Board Owner). Call backend function to remove member from `boards/{boardId}/members` and disconnect their socket. |

---

## Module 6: Notifications & Preferences (FR15)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR15-05** | Enable or disable notifications in settings | ⚠️ Partial | 🟢 **Level 1.5 (1.5/5)** | In [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart), add a "Notifications" section with switches (Push Notifications, Invite Alerts, Friend Alerts). Link to [`notification_preferences.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/utils/notification_preferences.dart). |
| **FR15-04** | Notify users when mentioned in a comment | ❌ Missing | 🟠 **Level 3 (3/5)** | Parse `@displayName` regex in comments. When comment is submitted, query user UID and trigger Cloud Function [`send_notification.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/notifications/send_notification.js) with FCM payload and in-app notification. *(Depends on Module 11 Comment System).* |

---

## Module 7: Presence & Live Awareness (FR08)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR08-01** | Display active participants in board session | ⚠️ Partial | 🟡 **Level 2.5 (2.5/5)** | In [`server/src/index.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/server/src/index.js), maintain an in-memory set of connected `socket.data.uid` per room. Emit `active_participants_changed` to room. Display green "Online Now" indicators next to active peers in [`members_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/members_tray.dart). |
| **FR08-04**<br>**FR08-05** | Notify participants when a user joins or leaves board | ❌ Missing | 🟡 **Level 2.5 (2.5/5)** | In [`server/src/index.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/server/src/index.js), on `watch_board`, broadcast `peer_joined` with user name/avatar; on `leave_board` or `disconnect`, broadcast `peer_left`. In [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart), show transient floating toast / snackbar. |
| **FR08-03** | Indicate which participant is editing an object | ❌ Missing | 🟠 **Level 3.5 (3.5/5)** | When a user selects/transforms an element, broadcast ephemeral `peer_select_element` via Socket.IO with `elementId`, `uid`, and peer color. In `_CanvasPainter`, draw a colored bounding box with the peer’s name pill above the active element. |
| **FR08-02** | Show live cursor positions of active participants | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Capture pointer move in `Listener` / `GestureDetector` on canvas.<br>2. Send throttled (e.g. 50ms) `peer_cursor_move` events `{x, y}` to Socket server.<br>3. Server broadcasts to room peers.<br>4. In [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart), render remote arrow pointers + name tags matching transformed viewport scale/offset. |

---

## Module 8: Board Export & File Sharing (FR11)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR11-03** | Share exported file | ❌ Missing | 🟢 **Level 1.5 (1.5/5)** | Add `share_plus: ^10.1.0` to [`pubspec.yaml`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/pubspec.yaml). Call `Share.shareXFiles([XFile(filePath)], text: 'Exported board from InkLink')` when any export completes. |
| **FR11-01**<br>**FR11-04** | Export board as PNG image with layout integrity | ❌ Missing | 🟡 **Level 2.5 (2.5/5)** | Calculate bounding box of all canvas elements. Render offscreen onto a `PictureRecorder` + `Canvas` at 2x/3x scale. Convert to image (`toByteData(format: ImageByteFormat.png)`). Save to device storage via `path_provider`. Add "Export as PNG" to canvas menu. |
| **FR11-02** | Export board as PDF file | ❌ Missing | 🟠 **Level 3.5 (3.5/5)** | Add `pdf: ^3.11.1` and `printing: ^5.13.2` to `pubspec.yaml`. Create a PDF document containing a full-resolution vector/raster page layout of the canvas elements with title header and metadata footer. Add "Export as PDF" to canvas menu. |
| **FR11-05** | Export boards as SVG files | ❌ Missing | 🟠 **Level 3.5 (3.5/5)** | Build an `SvgExporter` class that iterates through all `CanvasElement` models: translate strokes into `<path d="...">`, shapes into `<rect>`, `<circle>`, `<polygon>`, text into `<text>`, and images into embedded `<image>`. Write `.svg` string to file. |

---

## Module 9: Public Board Access & Discovery (FR14)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR14-02** | Deep link routing for public boards | ⚠️ Partial | 🟡 **Level 2.5 (2.5/5)** | Configure deep linking schemes in `AndroidManifest.xml` and `Info.plist` (e.g. `inklink://board/:id` or Universal Links). Parse incoming link on app start and route directly to `CanvasRoute(boardId)`. |
| **FR14-11**<br>**FR14-12** | Index tags to support efficient public filtering | ⚠️ Partial | 🟡 **Level 2.5 (2.5/5)** | Update [`firestore.indexes.json`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/firestore.indexes.json) with compound index on `boards` for `visibility == 'public'` + `tags` (array-contains) + `createdAt` (descending). |
| **FR14-04**<br>**FR14-05** | Dedicated screen for browsing public boards | ❌ Missing | 🟠 **Level 3 (3/5)** | Create `PublicBoardDiscoveryScreen` in `features/dashboard/view/` or navigation bar. Query Firestore `boards` collection where `visibility == 'public'` with pagination. Render public board cards with thumbnails, tags, and member count. |
| **FR14-06**<br>**FR14-07** | Search & filter public boards by title, keywords & tags | ❌ Missing | 🟠 **Level 3 (3/5)** | Add search bar and horizontal filter chip list of popular tags at the top of the discovery screen. Query by search keywords array or tag filter selection. |
| **FR14-16** | Sort public boards (most popular, most recent) | ❌ Missing | 🟠 **Level 3 (3/5)** | Add sorting dropdown (Recent: `createdAt DESC`, Popular: `membersCount DESC`). Maintain `membersCount` integer field on boards for indexed order-by queries. |
| **FR14-08**<br>**FR14-09**<br>**FR14-10** | Tag-based board recommendation feed | ❌ Missing | 🟠 **Level 3.5 (3.5/5)** | In `PublicBoardsBloc`, fetch user's `preferredTags` (FR02-12). Query public boards matching user's preferred tags using `array-contains-any`. Rank matching boards at top of discovery feed; refresh dynamically when user updates tag preferences. |

---

## Module 10: AI-Assisted Object Generation & Limits (FR06 & FR16)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR06-08** | Validate AI prompt length | ❌ Missing | 🟢 **Level 1 (1/5)** | In [`ai_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/ai_tray.dart), enforce prompt character limit (e.g., 5 to 300 chars) with character counter indicator and disable generate button if invalid. |
| **FR16-01**<br>**FR16-02** | Track AI requests & enforce per-user quota limits | ❌ Missing | 🟠 **Level 3 (3/5)** | In Firestore, create subcollection `users/{uid}/ai_usage` or daily counter fields (`dailyAiCount`, `lastAiReset`). In Cloud Function, verify user hasn't exceeded quota (e.g. 20 generations/day). If exceeded, reject with `resource-exhausted` code. |
| **FR06-01**<br>to<br>**FR06-07** | End-to-end AI object generation and canvas insertion | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Create Cloud Function `generateAiCanvasObject.js` using Google GenAI SDK (Gemini API).<br>2. Prompt Gemini to generate either structured vector graphics (shapes, diagrams, layout) or image bitmap.<br>3. Parse JSON response into `ShapeElement` / `TextElement` or upload image to R2 and return `ImageElement`.<br>4. Client receives payload and triggers `CanvasAddElementRequested`.<br>5. Handle errors with user-friendly snackbars. |

---

## Module 11: In-App Communication & Audio (FR12)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR12-01**<br>**FR12-02**<br>**FR12-03**<br>**FR12-05** | Board Canvas Text Comments, Replies & Mentions | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Create `Comment` model (`id`, `boardId`, `x`, `y`, `authorUid`, `text`, `createdAt`, `replies`).<br>2. Store in Firestore subcollection `boards/{boardId}/comments`.<br>3. Render comment pin markers on canvas viewport.<br>4. Tap pin to open threaded comment bottom sheet with reply and delete capabilities.<br>5. Dispatch notifications on new comment / reply. |
| **FR12-04** | Live in-board chat for active participants | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Replace placeholder button in [`members_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/members_tray.dart#L86-L92) with a slide-out Chat Drawer.<br>2. Stream chat messages over Socket.IO room `board_room:${boardId}` via `board_chat_message` events.<br>3. Store in Firestore `boards/{boardId}/chat_messages` for session persistence.<br>4. Unread badge indicator on chat icon. |
| **FR12-06**<br>**FR12-07** | Initiate and join/leave in-session Voice Calls | ❌ Missing | 🟣 **Level 5 (5/5)** | 1. Integrate WebRTC or audio provider (e.g., LiveKit, Agora, or flutter_webrtc with SFU signaling).<br>2. Add audio room signaling to Socket.IO server (`voice_join`, `voice_leave`, `ice_candidate`, `offer_answer`).<br>3. Request microphone permissions (`permission_handler`).<br>4. Build in-canvas voice HUD showing speaking indicators, mute/unmute toggle, and disconnect button. |

---

## Module 12: Direct Messaging (DM) System (FR17)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR17-01**<br>**FR17-02** | Initiate DMs & manage unique conversation threads | ❌ Missing | 🟠 **Level 3 (3/5)** | 1. Define `DirectMessageThread` (`threadId = min(uid1,uid2) + "_" + max(uid1,uid2)`, `participantUids`, `lastMessage`, `updatedAt`).<br>2. In [`friends_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/friends/view/friends_screen.dart), add "Message" button to each friend card that routes to `DirectMessageScreen(threadId)`. |
| **FR17-03**<br>**FR17-04** | Real-time messaging & persistent message history | ❌ Missing | 🟠 **Level 3.5 (3.5/5)** | 1. Create `DirectMessage` model (`id`, `threadId`, `senderUid`, `text`, `timestamp`, `status`).<br>2. Store messages in Firestore `threads/{threadId}/messages` ordered by timestamp.<br>3. Stream messages via Firestore snapshots or Socket.IO user rooms. Build reactive chat bubble UI with auto-scroll. |
| **FR17-07**<br>**FR17-10**<br>**FR17-11** | Validate content, edit sent messages & delete messages | ❌ Missing | 🟠 **Level 3.5 (3.5/5)** | 1. Client-side trim, max length (2000 chars), and empty message validation.<br>2. Long-press message bubble menu: "Edit" and "Delete".<br>3. Update message document with `isEdited: true` or `isDeleted: true` (soft delete). |
| **FR17-08**<br>**FR17-09** | Real-time status updates (sent/delivered/read) & push alerts | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Track message delivery and read receipts (`status: 'sent' | 'delivered' | 'read'`) using Firestore field updates when recipient opens thread.<br>2. Cloud Function `onDirectMessageCreated` dispatches FCM notification to recipient device when app is backgrounded. |
| **FR17-06** | Support multiple message types (text, images, files) | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Support `messageType: 'text' | 'image' | 'file'` in message model.<br>2. Add attachment picker in chat input bar.<br>3. Upload media attachments to Cloudflare R2 / Firebase Storage with file constraints (max 10MB image, max 25MB file).<br>4. Render media previews inside chat bubbles. |
| **FR17-05**<br>**FR17-12** | Offline message sending, queue & cross-device sync | ❌ Missing | 🟣 **Level 4.5 (4.5/5)** | 1. Create `LocalDirectMessage` collection in Isar DB with `syncStatus: 'pending' | 'synced'`.<br>2. Optimistically append messages to chat UI when offline.<br>3. Background sync manager detects reconnection and flushes pending offline queue in chronological order to server.<br>4. Reconcile server timestamps and update local IDs. |

---

## Cross-Module Global Backlog Summary

Ordered strictly from **Lowest Complexity (Quickest Wins)** to **Highest Complexity (Subsystem Engines)**:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟢 LEVEL 1 & 1.5: QUICK WINS (1 – 3 HOURS EACH)                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 1. [FR01-04] Password strength rules regex in helpers.dart (✅ Done)            │
│ 2. [FR03-13] Board tags format & length validation                             │
│ 3. [FR05-16] Camera image capture option for canvas images                     │
│ 4. [FR06-08] AI prompt character length validation                             │
│ 5. [FR01-05] Trigger email verification email on registration (✅ Done)         │
│ 6. [FR01-07] Wire up password reset email flow in login screen (✅ Done)        │
│ 7. [FR02-04] Strict PNG/JPEG/JPG MIME validation for profile photos            │
│ 8. [FR11-03] Native file share sheet integration with share_plus               │
│ 9. [FR15-05] Notification preference switches in settings screen               │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟡 LEVEL 2 & 2.5: STANDARD FEATURES & SERVICES (4 – 8 HOURS EACH)              │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 10. [FR01-06] Enforce email verification check on user login (✅ Done)          │
│ 11. [FR02-10] User profile privacy settings (online status, visibility)        │
│ 12. [FR02-11/12] User preferred tags picker & storage in profile               │
│ 13. [FR02-05] Settings preferences persistence to Firestore                    │
│ 14. [FR03-08] Archive / unarchive boards functionality                         │
│ 15. [FR05-04] Predefined Arrow shape implementation in CanvasPainter           │
│ 16. [FR07-05] Direct board member access revocation button in MembersTray      │
│ 17. [FR03-07] Duplicate board functionality with CRDT snapshot cloning         │
│ 18. [FR03-11] Atomic move boards between workspaces                            │
│ 19. [FR08-01] Active online peers indicator in MembersTray                     │
│ 20. [FR08-04/05] User join/leave toast notifications over WebSockets           │
│ 21. [FR11-01/04] Export canvas as high-resolution PNG image                    │
│ 22. [FR14-02] Public board deep linking scheme (inklink://board/:id)           │
│ 23. [FR14-11/12] Compound indexing for public boards & tags in firestore       │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟠 LEVEL 3 & 3.5: MODERATE SUBSYSTEMS & SCREENS (1 – 2 DAYS EACH)              │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 24. [FR02-06/07] Account deletion with cascading data purge Cloud Function     │
│ 25. [FR05-09] Canvas Sticky Note visual elements with text wrapping            │
│ 26. [FR11-02] Export canvas as paginated PDF document                          │
│ 27. [FR11-05] Vector SVG serialization and export pipeline                     │
│ 28. [FR14-04/05] Dedicated Public Board Discovery Screen & feed                │
│ 29. [FR14-06/07] Public board search and tag filter chips                      │
│ 30. [FR14-16] Public board sorting (most popular, most recent)                 │
│ 31. [FR14-08..10] Preferred tag-based public board recommendations feed        │
│ 32. [FR15-04] Comment @mention notifications parsing and FCM dispatch         │
│ 33. [FR16-01/02] AI per-user request usage tracking and daily quota limit      │
│ 34. [FR08-03] Remote peer active element editing indicator / lock badge        │
│ 35. [FR17-01/02] Direct Message thread management & friends message button     │
│ 36. [FR17-03/04] Real-time DM messaging stream & message bubble UI             │
│ 37. [FR17-07/10/11] Message validation, editing sent messages, soft delete     │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🔴 LEVEL 4 & 4.5: ADVANCED ENGINES & PIPELINES (3 – 5 DAYS EACH)               │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 38. [FR05-13..15] Connectors & Flowchart diagram elements with linked topology │
│ 39. [FR08-02] Real-time live peer cursor broadcasting & canvas painter         │
│ 40. [FR06-01..07] AI object generation via Gemini API & canvas insertion       │
│ 41. [FR12-01..03/05] Pin-to-canvas threaded comments with replies              │
│ 42. [FR12-04] Live in-board session chat drawer over WebSockets                │
│ 43. [FR17-08/09] DM delivery/read receipts & push notifications on new message │
│ 44. [FR17-06] DM rich media attachments (images, files via Cloudflare R2)      │
│ 45. [FR17-05/12] Offline DM message queue with Isar DB & reconnection sync     │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟣 LEVEL 5: MAJOR SUBSYSTEM (1 – 2 WEEKS)                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 46. [FR12-06/07] Live in-session WebRTC Voice Calling system & audio HUD       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

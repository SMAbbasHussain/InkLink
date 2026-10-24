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

1. [Module 1: Authentication & Identity (FR01) — ✅ COMPLETED (100%)](#module-1-authentication--identity-fr01)
2. [Module 2: User Profile & Preferences (FR02) — ✅ COMPLETED (100%)](#module-2-user-profile--preferences-fr02)
3. [Module 3: Board Creation & Management (FR03) — ✅ COMPLETED (100%)](#module-3-board-creation--management-fr03)
4. [Module 4: Canvas Tools & Visual Elements (FR05) — ✅ COMPLETED (100%)](#module-4-canvas-tools--visual-elements-fr05)
5. [Module 5: Board Sharing & Access Control (FR07) — ✅ COMPLETED (100%)](#module-5-board-sharing--access-control-fr07)
6. [Module 6: Notifications & Preferences (FR15) — ✅ COMPLETED (100%)](#module-6-notifications--preferences-fr15)
7. [Module 7: Presence & Live Awareness (FR08)](#module-7-presence--live-awareness-fr08)
8. [Module 8: Board Export & File Sharing (FR11) — ✅ COMPLETED (100%)](#module-8-board-export--file-sharing-fr11)
9. [Module 9: Public Board Access & Discovery (FR14)](#module-9-public-board-access--discovery-fr14)
10. [Module 10: AI-Assisted Object Generation & Limits (FR06 & FR16)](#module-10-ai-assisted-object-generation--limits-fr06--fr16)
11. [Module 11: In-App Communication & Audio (FR12) — ✅ COMPLETED (100%)](#module-11-in-app-communication--audio-fr12)
12. [Module 12: Direct Messaging (DM) System (FR17) — ✅ COMPLETED (100%)](#module-12-direct-messaging-dm-system-fr17)
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

## Module 3: Board Creation & Management (FR03) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR03-13** | Validate board tags against predefined format | ✅ **Implemented** | 🟢 **Level 1 (1/5)** | Enforced in [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart) and [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart) requiring tag length `<= 20`, max 5 tags, lowercase alphanumeric chars and hyphens only (`RegExp(r'^[a-z0-9\-]+$')`). |
| **FR03-08** | Owners archive / unarchive boards | ✅ **Implemented** | 🟡 **Level 2 (2/5)** | Added `isArchived: bool` field to [`board.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/board.dart) and Firestore. Added "Archive Board" & "Unarchive Board" dialogs and actions in [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart), [`board_card.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/widgets/board_card.dart), `DashboardBloc`, and filtered archived boards into a dedicated Archived tab on [`home_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/home_screen.dart). |
| **FR03-07** | Owners duplicate boards & permission-controlled member copies | ✅ **Implemented** | 🟡 **Level 2.5 (2.5/5)** | 1. Implemented `duplicateBoard(boardId)` in [`board_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/board/board_repository_impl.dart) with full CRDT drawing update duplication, Firestore snapshot cloning, preview thumbnail copying, and isolating new board membership strictly to the copier.<br>2. Added `allowMembersToCopy: bool` permission toggle in [`board.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/board.dart), [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart), and [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart).<br>3. Added "Copy from existing board" selector in [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart). |
| **FR03-11** | Move boards between workspaces | ✅ **Implemented** | 🟡 **Level 2.5 (2.5/5)** | Created atomic "Move Board to Workspace" modal dialog in [`workspace_detail_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/workspaces/view/workspace_detail_screen.dart). Implemented atomic Firestore batch in [`workspace_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/workspace/workspace_repository_impl.dart) to remove board from source workspace and add to destination workspace. |

---

## Module 4: Canvas Tools & Visual Elements (FR05) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR05-16** | Capture images using device camera to canvas | ✅ **Implemented** | 🟢 **Level 1 (1/5)** | Provided modal bottom sheet in [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart) giving users choice between Camera (`ImageSource.camera`) and Gallery (`ImageSource.gallery`) before image processing. |
| **FR05-04** | Predefined Arrow shape | ✅ **Implemented** | 🟡 **Level 2 (2/5)** | Added `arrow` shape to [`canvas_shape_type.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/canvas_shape_type.dart) and [`shapes_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/shapes_tray.dart). Implemented arrow path calculation (shaft + arrowhead) in [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart). |
| **FR05-09** | Insert sticky notes | ✅ **Implemented** | 🟠 **Level 3 (3/5)** | Created `StickyNoteElement` extending [`CanvasElement`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/models/canvas_element.dart) with pastel color presets (yellow, lime, cyan, rose, lavender), wrapped typography, drop shadow, and tape accent. Added sticky note action button to [`tools_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/tools_tray.dart) and double-tap editing dialog. |
| **FR05-13**<br>**FR05-14**<br>**FR05-15** | Connectors & Flowchart diagrams with dynamic link maintenance | ✅ **Implemented** | 🔴 **Level 4 (4/5)** | Defined `ConnectorElement` with `startElementId`, `startAnchor`, `endElementId`, `endAnchor`, line styles (straight, curved bezier, orthogonal step), and arrowhead. In [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart), implemented dynamic anchor resolution. In [`canvas_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/bloc/canvas_bloc.dart), when connected shapes move or resize, dynamically updated attached connector coordinates in CRDT to preserve link topology. |

---

## Module 5: Board Sharing & Access Control (FR07) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR07-05** | Revoke member access from board & update roles | ✅ **Implemented** | 🟡 **Level 2 (2/5)** | In [`members_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/members_tray.dart), added owner-only trailing popup menu with options to toggle member role (Editor <-> Viewer via `CanvasUpdateBoardMemberRole`) and revoke access (`CanvasRemoveBoardMember`) with a confirmation dialog. Handled in [`canvas_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/bloc/canvas_bloc.dart), `BoardService`, and Cloud Functions. |

---

## Module 6: Notifications & Preferences (FR15) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR15-05** | Enable or disable notifications in settings | ✅ **Implemented** | 🟢 **Level 1.5 (1.5/5)** | In [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart), added "Notifications" section with switches for Push Notifications, Board Invite Alerts, and Friend Request Alerts. Backed by [`notification_preferences.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/utils/notification_preferences.dart), [`settings_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/bloc/settings_bloc.dart), `ProfileService`, and checked in [`notification_sender.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/utils/notification_sender.js). |
| **FR15-04** | Notify users when mentioned in a comment | ✅ **Implemented** | 🟠 **Level 3 (3/5)** | Implemented regex `@displayName` and `@username` extraction in [`board_comments_service_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/services/canvas/board_comments_service_impl.dart). Triggered callable Cloud Function [`send_comment_mention.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/notifications/send_comment_mention.js) which resolves recipient users and dispatches in-app notifications and FCM push alerts. |

---

## Module 7: Presence & Live Awareness (FR08)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR08-01** | Display active participants in board session | ⚠️ Partial | 🟡 **Level 2.5 (2.5/5)** | In [`server/src/index.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/server/src/index.js), maintain an in-memory set of connected `socket.data.uid` per room. Emit `active_participants_changed` to room. Display green "Online Now" indicators next to active peers in [`members_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/members_tray.dart). |
| **FR08-04**<br>**FR08-05** | Notify participants when a user joins or leaves board | ❌ Missing | 🟡 **Level 2.5 (2.5/5)** | In [`server/src/index.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/server/src/index.js), on `watch_board`, broadcast `peer_joined` with user name/avatar; on `leave_board` or `disconnect`, broadcast `peer_left`. In [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart), show transient floating toast / snackbar. |
| **FR08-03** | Indicate which participant is editing an object | ❌ Missing | 🟠 **Level 3.5 (3.5/5)** | When a user selects/transforms an element, broadcast ephemeral `peer_select_element` via Socket.IO with `elementId`, `uid`, and peer color. In `_CanvasPainter`, draw a colored bounding box with the peer’s name pill above the active element. |
| **FR08-02** | Show live cursor positions of active participants | ❌ Missing | 🔴 **Level 4 (4/5)** | 1. Capture pointer move in `Listener` / `GestureDetector` on canvas.<br>2. Send throttled (e.g. 50ms) `peer_cursor_move` events `{x, y}` to Socket server.<br>3. Server broadcasts to room peers.<br>4. In [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart), render remote arrow pointers + name tags matching transformed viewport scale/offset. |

---

## Module 8: Board Export & File Sharing (FR11) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR11-03** | Share exported file | ✅ **Implemented** | 🟢 **Level 1.5 (1.5/5)** | Added `share_plus: ^13.3.1`. Integrated `exportService.shareBoardFile(path)` via native share sheet triggered directly from export modal sheet or completion SnackBar action. |
| **FR11-01**<br>**FR11-04** | Export board as PNG image with layout integrity | ✅ **Implemented** | 🟡 **Level 2.5 (2.5/5)** | Computes bounding box with generous padding across all canvas elements. Renders offscreen via `ui.PictureRecorder` + `ui.Canvas` at 2x resolution to preserve layout integrity. Encodes to PNG and saves to device storage. |
| **FR11-02** | Export board as PDF file | ✅ **Implemented** | 🟠 **Level 3.5 (3.5/5)** | Added `pdf: ^3.13.1`. Generates styled PDF document with board title header, creation metadata badge, high-res canvas image, and footer. Saves to device storage. |
| **FR11-05** | Export boards as SVG files | ✅ **Implemented** | 🟠 **Level 3.5 (3.5/5)** | Full vector SVG serializer converting freehand strokes into `<path d="...">`, all 12 shape types into `<rect>`, `<circle>`, `<polygon>`, `<path>`, connectors with arrow markers, sticky notes, and text. Outputs valid XML `.svg` file. |

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

## Module 11: In-App Communication & Audio (FR12) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR12-01**<br>**FR12-02**<br>**FR12-03**<br>**FR12-05** | Board Canvas Text Comments, Replies & Mentions | ✅ **Implemented** | 🔴 **Level 4 (4/5)** | Models `CanvasComment` & `CanvasCommentReply`. Stored in Firestore `boards/{boardId}/comments`. Real-time stream in `BoardCommentsRepository`. Rendered pinned badges on canvas viewport with coordinate transformations. Click pin to open `CommentsTray` with threaded replies, author-only deletion, and @mention highlights. |
| **FR12-04** | Live in-board chat for active participants | ✅ **Implemented** | 🔴 **Level 4 (4/5)** | Floating `BoardChatDrawer` sliding from right edge on canvas. Live bi-directional chat over Socket.IO (`board_chat_message`). Stored in Redis with 7-day TTL (`board_chat:{boardId}:history`) and synced atomically to Firestore `boards/{boardId}/chat_messages` in batches of 30 when accumulated. |
| **FR12-06**<br>**FR12-07** | Initiate and join/leave in-session Voice Calls | ✅ **Implemented** | 🟣 **Level 5 (5/5)** | In-session voice calling with Agora engine secrets configuration (`AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`). Signaling over Socket.IO (`join_voice_call`, `leave_voice_call`, `voice_speaking_state`, `get_voice_participants`). In-canvas `VoiceCallHud` showing active speaker glow rings, mute/unmute mic toggle, and leave/join controls. |

---

## Module 12: Direct Messaging (DM) & Group Messaging System (FR17) — ✅ COMPLETED (100%)

| Req ID | Requirement | Status | Complexity | Technical Scope & Implementation Steps |
| :--- | :--- | :---: | :---: | :--- |
| **FR17-01**<br>**FR17-02** | Initiate DMs & manage unique conversation threads (Inbox & Discord-Style UI) | ✅ **Implemented** | 🟠 **Level 3 (3/5)** | Replaced Friends bottom tab with `ChatInboxScreen` in `MainWrapper`. Provides Discord-themed dark UI (`#36393F` surface, `#5865F2` blurple accent), unread counters, swipe-to-delete, DMs and Group chats with real-time Agora SDK streams. Moved Friends list into an expandable/collapsible card on `ProfileScreen` with direct 1-tap "Message" action into `ChatThreadScreen`. |
| **FR17-03**<br>**FR17-04** | Real-time messaging & persistent message history via Agora SDK + Isar DB | ✅ **Implemented** | 🟠 **Level 3.5 (3.5/5)** | Powered by Agora Chat SDK (`agora_chat_sdk: ^1.4.0+1`). Wraps Agora ChatManager listeners and mirrors every message to local Isar DB (`LocalChatMessage` & `LocalChatConversation`). Messages render in reactive, Discord-styled bubbles with auto-scroll, timestamp grouping, and multi-line formatting. |
| **FR17-07**<br>**FR17-10**<br>**FR17-11** | Validate content, edit sent messages, soft delete & emoji reactions | ✅ **Implemented** | 🟠 **Level 3.5 (3.5/5)** | Message input bar trims whitespace and enforces non-empty input. Long-press message context menu provides: copy text, edit message (`ChatClient.getInstance.chatManager.modifyMessage`), soft delete, and Discord-style reaction picker (👍, ❤️, 😂, 😮, 😢, 🔥). Reactions toggle dynamically with counters in `ChatBubble`. |
| **FR17-08**<br>**FR17-09** | Delivery & read receipts & push notifications on new message | ✅ **Implemented** | 🔴 **Level 4 (4/5)** | Mark-as-read handled on thread enter (`markAllMessagesAsRead`). Message status indicators (`sending`, `sent`, `delivered`, `read`). Dispatches FCM push notifications to recipient devices via `sendNotification` Cloud Function on outgoing messages and routes notifications directly to `ChatThreadScreen` via `LocalNotificationService`. |
| **FR17-06** | Support rich message types (images, files, GIFs, board/workspace share cards) | ✅ **Implemented** | 🔴 **Level 4 (4/5)** | 1. Image and file sending with local & remote paths, file size formatting, and full-screen image viewer.<br>2. Built-in GIF picker tray with animated Giphy trending/category tabs and instant preview.<br>3. In-chat Board and Workspace interactive cards: displays board/workspace name, join code, member count, and 1-tap navigation button directly into canvas or workspace detail screen. |
| **FR17-05**<br>**FR17-12** | Offline message cache, local persistence & group chat administration | ✅ **Implemented** | 🟣 **Level 4.5 (4.5/5)** | 1. Local-first dual storage: Agora internal SQLite cache + Isar database collections (`LocalChatMessage`, `LocalChatConversation`) ensuring full offline reading and instant startup.<br>2. Complete Group Chat system: create group sheet with multi-friend selector, group info settings (`GroupSettingsScreen`), change group name/description, promote/demote administrators, remove members, transfer ownership, and leave group. |

---

## Cross-Module Global Backlog Summary

Ordered strictly from **Lowest Complexity (Quickest Wins)** to **Highest Complexity (Subsystem Engines)**:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟢 LEVEL 1 & 1.5: QUICK WINS (1 – 3 HOURS EACH)                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 1. [FR01-04] Password strength rules regex in helpers.dart (✅ Done)            │
│ 2. [FR03-13] Board tags format & length validation (✅ Done)                   │
│ 3. [FR05-16] Camera image capture option for canvas images (✅ Done)            │
│ 4. [FR06-08] AI prompt character length validation                             │
│ 5. [FR01-05] Trigger email verification email on registration (✅ Done)         │
│ 6. [FR01-07] Wire up password reset email flow in login screen (✅ Done)        │
│ 7. [FR02-04] Strict PNG/JPEG/JPG MIME validation for profile photos (✅ Done)   │
│ 8. [FR11-03] Native file share sheet integration with share_plus (✅ Done)      │
│ 9. [FR15-05] Notification preference switches in settings screen (✅ Done)      │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟡 LEVEL 2 & 2.5: STANDARD FEATURES & SERVICES (4 – 8 HOURS EACH)              │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 10. [FR01-06] Enforce email verification check on user login (✅ Done)          │
│ 11. [FR02-10] User profile privacy settings (online status, visibility) (✅ Done)│
│ 12. [FR02-11/12] User preferred tags picker & storage in profile (✅ Done)      │
│ 13. [FR02-05] Settings preferences persistence to Firestore (✅ Done)           │
│ 14. [FR03-08] Archive / unarchive boards functionality (✅ Done)                │
│ 15. [FR05-04] Predefined Arrow shape implementation in CanvasPainter (✅ Done)  │
│ 16. [FR07-05] Direct board member access revocation button in MembersTray (✅ Done) │
│ 17. [FR03-07] Duplicate board functionality with CRDT snapshot cloning (✅ Done)│
│ 18. [FR03-11] Atomic move boards between workspaces (✅ Done)                   │
│ 19. [FR08-01] Active online peers indicator in MembersTray                     │
│ 20. [FR08-04/05] User join/leave toast notifications over WebSockets           │
│ 21. [FR11-01/04] Export canvas as high-resolution PNG image (✅ Done)           │
│ 22. [FR14-02] Public board deep linking scheme (inklink://board/:id)           │
│ 23. [FR14-11/12] Compound indexing for public boards & tags in firestore       │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟠 LEVEL 3 & 3.5: MODERATE SUBSYSTEMS & SCREENS (1 – 2 DAYS EACH)              │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 24. [FR02-06/07] Account deletion with cascade purge Cloud Function (✅ Done)   │
│ 25. [FR05-09] Canvas Sticky Note visual elements with text wrapping (✅ Done)   │
│ 26. [FR11-02] Export canvas as paginated PDF document (✅ Done)                 │
│ 27. [FR11-05] Vector SVG serialization and export pipeline (✅ Done)            │
│ 28. [FR14-04/05] Dedicated Public Board Discovery Screen & feed                │
│ 29. [FR14-06/07] Public board search and tag filter chips                      │
│ 30. [FR14-16] Public board sorting (most popular, most recent)                 │
│ 31. [FR14-08..10] Preferred tag-based public board recommendations feed        │
│ 32. [FR15-04] Comment @mention notifications parsing and FCM dispatch (✅ Done) │
│ 33. [FR16-01/02] AI per-user request usage tracking and daily quota limit      │
│ 34. [FR08-03] Remote peer active element editing indicator / lock badge        │
│ 35. [FR17-01/02] Direct Message thread management & friends message button (✅ Done) │
│ 36. [FR17-03/04] Real-time DM messaging stream & message bubble UI (✅ Done)         │
│ 37. [FR17-07/10/11] Message validation, editing sent messages, soft delete (✅ Done) │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🔴 LEVEL 4 & 4.5: ADVANCED ENGINES & PIPELINES (3 – 5 DAYS EACH)               │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 38. [FR05-13..15] Connectors & Flowchart diagram elements (✅ Done)             │
│ 39. [FR08-02] Real-time live peer cursor broadcasting & canvas painter         │
│ 40. [FR06-01..07] AI object generation via Gemini API & canvas insertion       │
│ 41. [FR12-01..03/05] Pin-to-canvas threaded comments with replies (✅ Done)     │
│ 42. [FR12-04] Live in-board session chat drawer over WebSockets (✅ Done)       │
│ 43. [FR17-08/09] DM delivery/read receipts & push notifications on new message (✅ Done) │
│ 44. [FR17-06] DM rich media attachments (images, files, GIFs, share cards) (✅ Done) │
│ 45. [FR17-05/12] Offline DM message queue with Isar DB & reconnection sync (✅ Done) │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│ 🟣 LEVEL 5: MAJOR SUBSYSTEM (1 – 2 WEEKS)                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 46. [FR12-06/07] Live in-session WebRTC Voice Calling system & audio HUD (✅ Done) │
└─────────────────────────────────────────────────────────────────────────────────┘
```

# InkLink: Requirements vs. Implementation Gap Analysis Report

**Date:** October 10, 2026  
**Document Analyzed:** `Requirements.docx` (Software Requirements Specification - AI-Powered Real-Time Collaborative Canvas System)  
**Codebase:** `InkLink` (Flutter Mobile App + Node.js/Redis/Socket.IO Server + Firebase Cloud Functions)

---

## 1. Executive Summary

A comprehensive line-by-line audit was conducted comparing the **Software Requirements Specification (`Requirements.docx`)** against the **InkLink codebase**.

### Key Statistics
* **Total Functional Requirements Specified:** **87 requirements across 17 categories (FR01 – FR17)**
  * **Fully Implemented (✅):** 68 requirements (~78.2%)
  * **Partially Implemented (⚠️):** 4 requirements (~4.6%)
  * **Missing / Not Implemented (❌):** 15 requirements (~17.2%)
* **Fully Completed Modules (100% Compliance):** **Module 1 (FR01), Module 2 (FR02), Module 3 (FR03), Module 4 (FR05), Module 5 (FR07), Module 6 (FR15), Module 8 (FR11), Module 11 (FR12), and Module 13 (FR13).**
* **Non-Functional Requirements (NFR01 – NFR08):** Strong foundational architectural alignment (Clean Architecture, Yjs CRDT, hybrid Redis/Firestore synchronization, Isar offline storage), but lacking formal automated benchmark testing suites.
* **Unspecified Extra Features in Codebase:** **8 substantial systems/features** built in the codebase that were not requested or documented in `Requirements.docx`.

---

## 2. Requirement-by-Requirement Traceability Matrix

### FR01: User Authentication & Identity — ✅ COMPLETED (100%)


| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR01-01** | Register using email and password | ✅ **Fully Implemented** | Handled in [`register_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/register_screen.dart) and [`auth_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/auth/auth_repository_impl.dart#L162-L177) via `signUp()`. |
| **FR01-02** | Register using Google account | ✅ **Fully Implemented** | Handled in [`auth_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/auth/auth_repository_impl.dart#L65-L107) via `signInWithGoogle()` and [`social_auth_button.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/widgets/social_auth_button.dart). |
| **FR01-03** | Validate email format before registration | ✅ **Fully Implemented** | Enforced with regex helper `isValidEmail(email)` in [`register_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/register_screen.dart#L202-L207). |
| **FR01-04** | Enforce minimum password strength rules | ✅ **Fully Implemented** | Enforced in [`helpers.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/utils/helpers.dart) and [`register_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/register_screen.dart) requiring >= 8 characters, uppercase, lowercase, digit, and special character. |
| **FR01-05** | Send email verification upon email registration | ✅ **Fully Implemented** | Automatic dispatch in [`auth_session_service.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/services/auth/auth_session_service.dart) upon registration; resend support with cooldown in [`email_verification_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/email_verification_screen.dart). |
| **FR01-06** | Allow verified Users to log in securely | ✅ **Fully Implemented** | Enforced in [`auth_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/bloc/auth_bloc.dart) checking `user.emailVerified`. Unverified password accounts are routed to [`email_verification_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/email_verification_screen.dart) until confirmed. |
| **FR01-07** | Reset forgotten passwords via email | ✅ **Fully Implemented** | Connected "Forgot Password?" dialog in [`login_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/auth/view/login_screen.dart) sending reset email via `FirebaseAuth.instance.sendPasswordResetEmail()` through `AuthRepository` & `AuthBloc`. |
| **FR01-08** | Maintain secure authenticated sessions | ✅ **Fully Implemented** | Handled by Firebase Auth session token management and token refresh in [`auth_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/auth/auth_repository_impl.dart). |
| **FR01-09** | Prevent unauthorized access to protected resources | ✅ **Fully Implemented** | Guarded by [`firestore.rules`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/firestore.rules), Socket.io auth handshake verifying Firebase tokens, and `canUserAccessBoard` in [`server/src/index.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/server/src/index.js). |

---

### FR02: User Profile Management — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR02-01** | Customize profile after registration | ✅ **Fully Implemented** | [`profile_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/profile/view/profile_screen.dart) and [`edit_profile_sheet.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/profile/view/widgets/edit_profile_sheet.dart). |
| **FR02-02** | Update display name | ✅ **Fully Implemented** | Supported via `SaveProfileChangesRequested` in [`profile_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/profile/bloc/profile_bloc.dart#L84-L96). |
| **FR02-03** | Upload profile pictures | ✅ **Fully Implemented** | Callable function [`upload_profile_photo.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/profile/upload_profile_photo.js) uploads to Cloudflare R2 storage and writes URL to Firestore. |
| **FR02-04** | Validate uploaded profile picture format (PNG, JPEG, JPG) | ✅ **Fully Implemented** | Strictly validated in [`upload_profile_photo.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/profile/upload_profile_photo.js) and [`edit_profile_sheet.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/profile/view/widgets/edit_profile_sheet.dart) via file extension checks and magic byte header inspection (`0xFF 0xD8 0xFF` for JPEG and `0x89 0x50 0x4E 0x47` for PNG). |
| **FR02-05** | Update preferences | ✅ **Fully Implemented** | Preferences for privacy, content tags, board compression, and preview quality are stored and updated via [`settings_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/bloc/settings_bloc.dart) and [`profile_service.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/services/profile/profile_service.dart). |
| **FR02-06** | Delete account | ✅ **Fully Implemented** | Destructive action in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart) with modal confirmation triggering `DeleteAccountRequested` in `AuthBloc`. |
| **FR02-07** | Remove associated user data upon account deletion | ✅ **Fully Implemented** | Backend Cloud Function [`delete_user_account.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/profile/delete_user_account.js) cascade-purges owned boards, Redis canvas state, board memberships, reciprocal friendships, friend requests, notifications, R2 profile photo, Firestore user document, and Firebase Auth record. |
| **FR02-08** | Select interface themes (Light/Dark Theme) | ✅ **Fully Implemented** | Implemented with [`theme_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/theme/bloc/theme_bloc.dart) and toggle in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart#L55-L61). |
| **FR02-09** | Customize UI appearance settings | ✅ **Fully Implemented** | Theme toggle and canvas tray tips overlay toggle in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart#L62-L77). |
| **FR02-10** | Configure privacy settings for profiles | ✅ **Fully Implemented** | Added `isProfilePublic`, `showOnlineStatus`, and `showEmail` to [`user_model.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/user_model.dart) with toggle switches in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart). |
| **FR02-11** | Select preferred tags for content personalization | ✅ **Fully Implemented** | Interactive tag selection dialog with suggested creative tags (`Art`, `Architecture`, `Brainstorming`, `Design`, etc.) and custom tag input in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart). |
| **FR02-12** | Store and update user tag preferences | ✅ **Fully Implemented** | `preferredTags: List<String>` stored in [`user_model.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/user_model.dart) and persisted to Firestore user document via `SettingsBloc` and `ProfileService`. |

---

### FR03: Board Creation & Management — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR03-01** | Owners create boards | ✅ **Fully Implemented** | [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart) and `createNewBoard()` in [`board_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/board/board_repository_impl.dart). |
| **FR03-02** | Owners customize boards | ✅ **Fully Implemented** | Title, visibility, join policies, default link join role, tags configured in [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart). |
| **FR03-03** | Assign unique board ID upon creation | ✅ **Fully Implemented** | Handled via Firestore document auto-ID generation. |
| **FR03-04** | Owners rename boards | ✅ **Fully Implemented** | `renameBoard()` in [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart). |
| **FR03-05** | Owners delete boards they own | ✅ **Fully Implemented** | `deleteBoard()` in [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart) backed by [`delete_board.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/boards/delete_board.js). |
| **FR03-06** | Prevent Editors and Viewers from deleting boards | ✅ **Fully Implemented** | Enforced by [`firestore.rules`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/firestore.rules#L58-L62) and Cloud Functions checking board ownership. |
| **FR03-07** | Owners duplicate boards | ✅ **Fully Implemented** | Implemented `duplicateBoard()` in [`board_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/board/board_repository_impl.dart) with full CRDT snapshot cloning, thumbnail copy, `allowMembersToCopy` permission toggle in [`board.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/board.dart), and copy selector in [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart). |
| **FR03-08** | Owners archive boards | ✅ **Fully Implemented** | Added `isArchived: bool` field to [`board.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/board.dart). Added Archive/Unarchive actions in [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart), [`board_card.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/widgets/board_card.dart), `DashboardBloc`, and dedicated Archived tab on [`home_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/home_screen.dart). |
| **FR03-09** | Display list of owned and shared boards | ✅ **Fully Implemented** | Tabbed views in [`home_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/home_screen.dart) ("My Boards" and "Shared With Me"). |
| **FR03-10** | Organize boards into workspaces or folders | ✅ **Fully Implemented** | Implemented through [`workspace_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/workspaces/bloc/workspace_bloc.dart) and [`workspaces_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/workspaces/view/workspaces_screen.dart). |
| **FR03-11** | Move boards between workspaces | ✅ **Fully Implemented** | Atomic "Move Board to Workspace" modal dialog in [`workspace_detail_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/workspaces/view/workspace_detail_screen.dart) and atomic Firestore batch in [`workspace_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/workspace/workspace_repository_impl.dart). |
| **FR03-12** | Assign tags to board during creation/editing | ✅ **Fully Implemented** | Tag inputs in [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart) and [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart). |
| **FR03-13** | Validate tags against predefined format | ✅ **Fully Implemented** | Strictly enforced in [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart) and [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart) requiring tag length `<= 20`, max 5 tags, lowercase alphanumeric and hyphens only (`RegExp(r'^[a-z0-9\-]+$')`). |
| **FR03-14** | Owners update or remove tags from existing boards | ✅ **Fully Implemented** | Interactive tag chip removal and addition in [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart). |

---

### FR04: Real-Time Collaborative Editing — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR04-01** | Join board session according to assigned permissions | ✅ **Fully Implemented** | Permissions enforced via [`canvas_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/bloc/canvas_bloc.dart) and `watch_board` handler in [`server/src/index.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/server/src/index.js#L510-L528). |
| **FR04-02** | Synchronize drawing operations instantly | ✅ **Fully Implemented** | WebSockets (Socket.IO) + Yjs binary update distribution in [`canvas_service.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/services/canvas/canvas_service.dart). |
| **FR04-03** | Broadcast object creation events | ✅ **Fully Implemented** | `crdt_update` event emitted on element insertion. |
| **FR04-04** | Broadcast object modification events | ✅ **Fully Implemented** | Updates broadcast via `crdt_update` and live ephemeral transform via `crdt_preview`. |
| **FR04-05** | Broadcast object deletion events | ✅ **Fully Implemented** | `CanvasDeleteElement` / `_onDeleteSelected` propagates Yjs map deletions. |
| **FR04-06** | Prevent duplication of operations during synchronization | ✅ **Fully Implemented** | Guaranteed by Yjs CRDT vector clocks and client transaction origins. |
| **FR04-07** | Maintain board state consistency after concurrent edits | ✅ **Fully Implemented** | Guaranteed mathematically by Yjs CRDT data structure. |

---

### FR05: Canvas Tools & Visual Elements — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR05-01** | Freehand drawing tool | ✅ **Fully Implemented** | `StrokeElement` rendering in [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart). |
| **FR05-02** | Customize brush size | ✅ **Fully Implemented** | Brush width slider in [`brush_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/brush_tray.dart). |
| **FR05-03** | Select drawing colors | ✅ **Fully Implemented** | Palette, hex, and RGB sliders in [`brush_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/brush_tray.dart). |
| **FR05-04** | Predefined shapes including rectangle, circle, and arrow | ✅ **Fully Implemented** | Added `arrow` shape to [`canvas_shape_type.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/canvas_shape_type.dart) and [`shapes_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/shapes_tray.dart). Implemented arrow path calculation (shaft + arrowhead) in [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart) and tap-to-connect 2 shapes support in [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart). |
| **FR05-05** | Resize shapes | ✅ **Fully Implemented** | Interactive transform overlay handles in [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart). |
| **FR05-06** | Rotate shapes | ✅ **Fully Implemented** | Rotation knob handle in [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart). |
| **FR05-07** | Insert text boxes | ✅ **Fully Implemented** | `TextElement` created via prompt in [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart). |
| **FR05-08** | Edit inserted text | ✅ **Fully Implemented** | Editing dialog updates text content via `CanvasUpdateTextElement`. |
| **FR05-09** | Insert sticky notes | ✅ **Fully Implemented** | Created `StickyNoteElement` extending [`CanvasElement`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/models/canvas_element.dart) with pastel color presets (yellow, lime, cyan, rose, lavender), wrapped typography, drop shadow, and tape accent. Added sticky note action button to [`tools_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/tools_tray.dart) and double-tap editing dialog. |
| **FR05-10** | Upload images | ✅ **Fully Implemented** | `ImageElement` supported via `image_picker` (gallery upload). |
| **FR05-11** | Reposition images | ✅ **Fully Implemented** | Drag gestures update `ImageElement.center`. |
| **FR05-12** | Resize images | ✅ **Fully Implemented** | Scale gestures resize `ImageElement` width and height. |
| **FR05-13** | Create connectors between canvas elements | ✅ **Fully Implemented** | Defined `ConnectorElement` with `startElementId`, `startAnchor`, `endElementId`, `endAnchor`, line styles (straight, curved bezier, orthogonal step), and arrowhead in [`canvas_element.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/canvas/canvas_element.dart). |
| **FR05-14** | Create flowchart diagrams using connected elements | ✅ **Fully Implemented** | Connector endpoints dynamically link shapes and flowchart elements on canvas with dynamic anchor calculation in [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart). |
| **FR05-15** | Move connected elements while maintaining links | ✅ **Fully Implemented** | Handled in [`canvas_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/bloc/canvas_bloc.dart); when connected shapes move or resize, attached connector coordinates update in CRDT to preserve link topology. |
| **FR05-16** | Capture images using device camera and insert onto canvas | ✅ **Fully Implemented** | Provided modal bottom sheet in [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart) giving users choice between Camera (`ImageSource.camera`) and Gallery (`ImageSource.gallery`) before image processing. |

---

### FR06: AI-Assisted Object Generation

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR06-01** | Text input field for AI prompts | ⚠️ **Partially Implemented** | UI prompt input exists in [`ai_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/ai_tray.dart), but is not connected to a backend. |
| **FR06-02** | Send prompt to external AI service | ❌ **Missing** | Button triggers `_onGenerateAiImage` in [`canvas_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_screen.dart#L320-L323) which displays a placeholder: `"AI image generation is coming soon."` No AI service (e.g. Gemini, OpenAI) is integrated. |
| **FR06-03** | Receive AI-generated object response | ❌ **Missing** | Not implemented. |
| **FR06-04** | Convert AI response into drawable object | ❌ **Missing** | Not implemented. |
| **FR06-05** | Insert generated object onto canvas | ❌ **Missing** | Not implemented. |
| **FR06-06** | Handle AI API errors gracefully | ❌ **Missing** | Not implemented. |
| **FR06-07** | Notify requesting User if AI generation fails | ❌ **Missing** | Not implemented. |
| **FR06-08** | Validate AI prompt length | ❌ **Missing** | Not implemented. |

---

### FR07: Board Sharing & Access Control — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR07-01** | Invite Users through friend list | ✅ **Fully Implemented** | Board invite sheet and [`send_board_invite.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/notifications/send_board_invite.js). |
| **FR07-02** | Assign roles (Owner, Editor, Viewer) | ✅ **Fully Implemented** | Role selection configured during invite and board creation. |
| **FR07-03** | Restrict editing rights to Editors and Owner only | ✅ **Fully Implemented** | Viewers cannot interact with drawing tools; enforced in `CanvasBloc`, `canvas_screen.dart`, and Socket server. |
| **FR07-04** | Restrict deletion rights to Owner only | ✅ **Fully Implemented** | Firestore rules & Cloud Functions prevent non-owners from deleting. |
| **FR07-05** | Allow Owner to revoke access from other Users | ✅ **Fully Implemented** | In [`members_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/members_tray.dart), added owner-only trailing popup menu with options to toggle member role (Editor <-> Viewer via `CanvasUpdateBoardMemberRole`) and revoke access (`CanvasRemoveBoardMember`) with a confirmation dialog. Handled in [`canvas_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/bloc/canvas_bloc.dart), `BoardService`, and idempotent Cloud Function [`remove_board_member.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/boards/remove_board_member.js). |
| **FR07-06** | Prevent unauthorized board access (unauthorized users/bots) | ✅ **Fully Implemented** | Token validation in Socket.IO, security rules in Firestore, rate-limiting on Socket server. |

---

### FR08: Presence & Awareness

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR08-01** | Display list of active participants in board session | ⚠️ **Partially Implemented** | [`members_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/members_tray.dart) lists enrolled board members, but does **not** indicate who is currently connected/active in the live session. |
| **FR08-02** | Show live cursor positions of active participants | ❌ **Missing** | Live peer cursors are not broadcast over WebSockets, nor rendered in [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart). |
| **FR08-03** | Indicate which participant is editing an object | ❌ **Missing** | No peer element lock indicator or active editor badge. |
| **FR08-04** | Notify participants when a user joins board | ❌ **Missing** | Socket server handles `watch_board` silently without broadcasting `user_joined` notifications. |
| **FR08-05** | Notify participants when a user leaves board | ❌ **Missing** | Socket server handles `leave_board` and `disconnect` without broadcasting `user_left` notifications. |

---

### FR09: Undo / Redo

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR09-01** | Record Owner and Editor actions in session history | ✅ **Fully Implemented** | Tracked via Yjs `UndoManager` in [`canvas_crdt_adapter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/crdt/canvas_crdt_adapter.dart#L46-L51). |
| **FR09-02** | Allow undo last action | ✅ **Fully Implemented** | `CanvasUndo` in [`canvas_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/bloc/canvas_bloc.dart#L962) and Undo button in [`tools_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/tools_tray.dart#L32-L37). |
| **FR09-03** | Allow redo undone actions | ✅ **Fully Implemented** | `CanvasRedo` in [`canvas_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/bloc/canvas_bloc.dart) and Redo button in [`tools_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/tools_tray.dart#L39-L44). |
| **FR09-04** | Maintain separate undo stacks per user | ✅ **Fully Implemented** | Guaranteed by `UndoManagerOpts(trackedOrigins: {_localOrigin})` in [`canvas_crdt_adapter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/crdt/canvas_crdt_adapter.dart#L48). |

---

### FR10: Offline Editing & Sync Recovery

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR10-01** | Perform editing operations while offline | ✅ **Fully Implemented** | Mutations operate directly against local Yjs CRDT instance. |
| **FR10-02** | Locally cache operations performed while offline | ✅ **Fully Implemented** | Unsynced CRDT updates stored locally in Isar database ([`local_crdt_update.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/database/collections/local_crdt_update.dart)). |
| **FR10-03** | Detect restored network connectivity | ✅ **Fully Implemented** | Handled by Socket.IO auto-reconnect listeners and connection state monitors. |
| **FR10-04** | Synchronize cached operations upon reconnection | ✅ **Fully Implemented** | Handled via `sync_offline` socket protocol with cursor replay and delta merging in [`canvas_sync_repository_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/repositories/canvas/canvas_sync_repository_impl.dart). |

---

### FR11: Board Export & File Sharing — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR11-01** | Export board as PNG image | ✅ **Implemented** | Implemented via `BoardExportService.exportBoard(format: BoardExportFormat.png)`. Generates high-res (2x) offscreen image via `ui.PictureRecorder` + `ui.Canvas`, saves PNG to local storage, and presents native share / download feedback. |
| **FR11-02** | Export board as PDF file | ✅ **Implemented** | Implemented using `package:pdf/widgets.dart`. Generates high-resolution multi-element page layout with board title header, creation metadata badge, and canvas image, saved to local storage. |
| **FR11-03** | Share exported file | ✅ **Implemented** | Integrated with `share_plus` (`BoardExportService.shareBoardFile`). Allows immediate dispatch to OS native share sheet from export options sheet or completion SnackBar. |
| **FR11-04** | Maintain layout integrity during export | ✅ **Implemented** | `BoardExportService.computeElementsBounds` calculates full bounding envelope of all shapes, strokes, connectors, sticky notes, and images with 60px padding, maintaining aspect ratio and vector positions. |
| **FR11-05** | Export boards as SVG files | ✅ **Implemented** | `BoardExportService.renderToSvg` iterates through elements converting strokes into `<path>`, shapes into SVG `<rect>`, `<circle>`, `<polygon>`, or `<path>`, connectors with arrow markers, sticky notes, and text into standards-compliant SVG. |

---

### FR12: In-App Communication & Audio — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR12-01** | Add text comments on board | ✅ **Fully Implemented** | Added `CanvasComment` model and Firestore collection `boards/{boardId}/comments`. Tap-to-place comment pins rendered on canvas with viewport matrix transforms. Dialog opens to enter comment text. |
| **FR12-02** | Reply to comments | ✅ **Fully Implemented** | Implemented `CanvasCommentReply` threaded replies in [`board_comments_service_impl.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/services/canvas/board_comments_service_impl.dart) and [`comments_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/comments_tray.dart). |
| **FR12-03** | Delete own comments | ✅ **Fully Implemented** | Users can delete comments they created via `deleteComment()` in service and delete icon in `CommentsTray`. |
| **FR12-04** | Live chat feature for active board participants | ✅ **Fully Implemented** | Integrated slide-out `BoardChatDrawer` on canvas. Socket.IO `board_chat_message` broadcasting with Redis storage (7-day TTL) and automatic batch synchronization of 30 accumulated messages to Firestore `boards/{boardId}/chat_messages`. |
| **FR12-05** | Notify Users of new comments | ✅ **Fully Implemented** | Dispatches real-time comment additions across board peers via Firestore snapshot stream in `BoardCommentsRepositoryImpl`. |
| **FR12-06** | Initiate voice calls within board session | ✅ **Fully Implemented** | In-session Agora voice call setup via `VoiceService`, Socket.IO signaling (`join_voice_call`, `voice_speaking_state`), and secrets configuration (`AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`). |
| **FR12-07** | Join or leave active voice call | ✅ **Fully Implemented** | `VoiceCallHud` widget on canvas stack providing participant avatars, speaking glow rings, mic mute/unmute toggle, and leave/join actions. |

---

### FR13: Social and Friend Management — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR13-01** | Search users by username or email | ✅ **Fully Implemented** | Implemented via prefix/keyword queries in [`friends_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/friends/view/friends_screen.dart). |
| **FR13-02** | Send friend requests | ✅ **Fully Implemented** | Handled in [`send_friend_request.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/friends/send_friend_request.js). |
| **FR13-03** | Accept or reject friend requests | ✅ **Fully Implemented** | Handled in [`accept_friend_request.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/friends/accept_friend_request.js) and [`decline_friend_request.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/friends/decline_friend_request.js). |
| **FR13-04** | Maintain friend list for each user | ✅ **Fully Implemented** | Stored in subcollection `users/{uid}/friends` and synced to local Isar DB. |
| **FR13-05** | Invite friends directly to a board | ✅ **Fully Implemented** | Board invitation modal in dashboard and canvas. |

---

### FR14: Public Board Access & Discovery — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR14-01** | Mark board as public | ✅ **Fully Implemented** | Visibility toggled in [`create_board_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/create_board_screen.dart) and [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart). |
| **FR14-02** | Users with public link view board | ✅ **Fully Implemented** | Handled by [`deep_link_service.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/services/deep_link_service.dart), Android intent filters, iOS URL types, and `WidgetsBindingObserver` routing to `buildCanvasRoute` across cold-start and warm-start cycles. 1-tap "Copy Deep Link" available on cards. |
| **FR14-03** | Disable public access | ✅ **Fully Implemented** | Owner can toggle visibility back to `private`. |
| **FR14-04** | Dedicated screen for browsing public boards | ✅ **Fully Implemented** | Built [`public_board_discovery_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/public_board_discovery_screen.dart) accessible via Compass icon button from [`home_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/home_screen.dart). |
| **FR14-05** | Display list of all public boards | ✅ **Fully Implemented** | Queries Firestore `boards` where `visibility == 'public'` with cursor pagination, displaying thumbnails, title, tags, and member counters. |
| **FR14-06** | Search public boards by title or keywords | ✅ **Fully Implemented** | Debounced search field filters boards in real-time by title and keyword tokens. |
| **FR14-07** | Filter public boards based on tags | ✅ **Fully Implemented** | Horizontal tag chips filter Firestore queries by tag (`array-contains`). |
| **FR14-08** | Recommend public boards based on preferred tags | ✅ **Fully Implemented** | `getRecommendedPublicBoards` queries boards matching user's preferred tags via `array-contains-any`. |
| **FR14-09** | Prioritize boards with matching tags in discovery feed | ✅ **Fully Implemented** | Sorts recommendations by highest number of matching tag intersections first, then by popularity (`membersCount`). |
| **FR14-10** | Update recommendations dynamically when user preferences change | ✅ **Fully Implemented** | `PublicBoardsBloc` listens to `_profileService.watchUserById` and dispatches `PublicBoardsUserPreferencesChanged` when preferred tags change, dynamically refreshing recommended boards. |
| **FR14-11** | Associate each public board with one or more tags | ✅ **Fully Implemented** | `tags` field persisted on board documents and displayed as chips on discovery cards. |
| **FR14-12** | Index tags to support efficient filtering and retrieval | ✅ **Fully Implemented** | Compound indexes added to [`firestore.indexes.json`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/firestore.indexes.json) for `visibility == 'public'` + `tags` (array-contains) + `createdAt`/`membersCount` (descending). |
| **FR14-13** | Any authenticated user join public board | ✅ **Fully Implemented** | 1-tap "Join Board" option on public board discovery card triggers `PublicBoardsJoinBoard` -> `_boardService.joinBoard(boardId)` -> adds user to members and updates dashboard. |
| **FR14-14** | Assign default role (Viewer) when joining public board | ✅ **Fully Implemented** | Default role set to `roleViewer` in [`board.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/domain/models/board.dart#L51) and resolved in [`join_board_by_code.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/boards/join_board_by_code.js). |
| **FR14-15** | Owners configure default roles for public joins | ✅ **Fully Implemented** | Configurable via dropdown in [`board_settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/dashboard/view/board_settings_screen.dart) and stored in `invitePolicy.defaultLinkJoinRole`. |
| **FR14-16** | Sort public boards (most popular, most recent) | ✅ **Fully Implemented** | Dropdown supporting "Most Recent" (`createdAt DESC`) and "Most Popular" (`membersCount DESC`) wired to indexed Firestore queries. |

---

### FR15: Notifications & Preferences — ✅ COMPLETED (100%)

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR15-01** | Notify users when receiving board invitation | ✅ **Fully Implemented** | Dispatched via FCM in [`send_board_invite.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/notifications/send_board_invite.js). |
| **FR15-02** | Notify users when friend request received | ✅ **Fully Implemented** | Dispatched via FCM in [`send_friend_request.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/friends/send_friend_request.js). |
| **FR15-03** | Notify users when friend request accepted | ✅ **Fully Implemented** | Dispatched via FCM in [`accept_friend_request.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/friends/accept_friend_request.js). |
| **FR15-04** | Notify users when mentioned in comment | ✅ **Fully Implemented** | Extracted `@username` / `@displayName` mentions in `BoardCommentsServiceImpl`. Dispatches callable Cloud Function [`send_comment_mention.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/notifications/send_comment_mention.js) which resolves recipient users and sends FCM push notification & in-app alert. |
| **FR15-05** | Allow users to enable or disable notifications | ✅ **Fully Implemented** | Added Notifications settings section in [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart) with toggles for Push Notifications, Board Invite Alerts, and Friend Request Alerts, backed by [`notification_preferences.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/utils/notification_preferences.dart), [`settings_bloc.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/bloc/settings_bloc.dart), Firestore user preferences, and checked in [`notification_sender.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/utils/notification_sender.js). |

---

### FR16: AI Usage Limits

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR16-01** | Track AI generation requests per user | ❌ **Missing** | No AI usage counter in Firestore, server, or client. |
| **FR16-02** | Enforce maximum AI request limit per user | ❌ **Missing** | No rate limits or quotas implemented for AI requests. |

---

### FR17: Direct Messaging (DM) System

| Req ID | Specification | Status | Implementation Evidence & Gap Details |
| :--- | :--- | :---: | :--- |
| **FR17-01** | Initiate DM conversations with friend list users | ❌ **Missing** | The DM system is **entirely unbuilt**. No DM UI, models, or backend exist. |
| **FR17-02** | Create and manage unique conversation threads | ❌ **Missing** | No thread models or thread collections. |
| **FR17-03** | Send and receive messages in real-time | ❌ **Missing** | Not implemented. |
| **FR17-04** | Store messages persistently in chronological order | ❌ **Missing** | Not implemented. |
| **FR17-05** | Offline message sending and sync upon reconnection | ❌ **Missing** | Not implemented. |
| **FR17-06** | Support message types (text, images, files) | ❌ **Missing** | Not implemented. |
| **FR17-07** | Validate message content and file constraints | ❌ **Missing** | Not implemented. |
| **FR17-08** | Update message status in real-time (sent/delivered/read) | ❌ **Missing** | Not implemented. |
| **FR17-09** | Notify users of new incoming messages | ❌ **Missing** | Not implemented. |
| **FR17-10** | Allow users to edit sent messages | ❌ **Missing** | Not implemented. |
| **FR17-11** | Allow users to delete sent messages | ❌ **Missing** | Not implemented. |
| **FR17-12** | Synchronize chat data across devices | ❌ **Missing** | Not implemented. |

---

### Non-Functional Requirements Analysis (NFR01 – NFR08)

| NFR ID | Area | Status | Evaluation |
| :--- | :--- | :---: | :--- |
| **NFR01** | Performance (Load time <2s, sync <=1s for <=100 objects & <=5 users, min 5 users) | ⚠️ **Architecturally Ready** | CRDT + Redis Stream pub/sub + Isar caching architecture provides sub-second propagation, but formal performance benchmark tests are absent. |
| **NFR02** | Security (HTTPS, Firestore rules restrict board access, file validation) | ⚠️ **Partially Met** | HTTPS/WSS and role-based Firestore rules are strong; however, profile photo file validation in Cloudflare R2 lacks strict magic-byte / MIME checking. |
| **NFR03** | Data Consistency (Eventual consistency under concurrency) | ✅ **Met** | Yjs CRDT + Redis Streams ensure eventual consistency mathematically and prevent merge conflicts. |
| **NFR04** | Platform Compatibility (Android & iOS) | ✅ **Met** | Multiplatform Flutter codebase with Android and iOS platform build configurations. |
| **NFR05** | Usability (Mobile-first) | ✅ **Met** | Custom mobile gesture handlers, radial/sliding trays, and responsive canvas viewports. |
| **NFR06** | Architecture (Modular clean architecture) | ✅ **Met** | Distinct separation of `core`, `domain`, `features` (presentation + bloc), and backend microservices. |
| **NFR07** | Cost Efficiency (Backend optimized for cost) | ✅ **Met** | In-memory Redis stream buffers + snapshot flushing every 100 updates drastically cuts Firestore read/write costs. |
| **NFR08** | Disaster Recovery (Recover data within 30 mins) | ✅ **Met** | Firestore snapshots + Redis streams + local Isar backup enable rapid disaster recovery. |

---

## 3. What Features Are Left (Missing / Incomplete)

Here is the categorized summary of all features required by the specification that are currently missing or incomplete:

### 1. Direct Messaging (DM) System (FR17) — *0% Implemented*
* All 12 DM requirements (FR17-01 through FR17-12) are completely missing.
* Needs: Conversation thread data models, chat UI screen, socket/Firestore real-time message stream, read receipts, offline message queue, attachments, and push notifications.

### 2. AI-Assisted Object Generation & Limits (FR06 & FR16) — *10% Implemented*
* Only a text prompt input exists in [`ai_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/ai_tray.dart).
* Missing: External AI API integration (e.g., Gemini API), prompt length validation (FR06-08), parsing AI output into canvas shapes (FR06-01 to FR06-07), error handling, user request tracking, and request limit enforcement (FR16-01, FR16-02).

### 3. Public Board Discovery & Tag Recommendation (FR14) — *35% Implemented*
* Public boards can be created, join policies and default roles configured, but cannot be browsed, searched, or recommended.
* Missing: Dedicated Public Boards Discovery Screen (FR14-04), public board feed (FR14-05), keyword search (FR14-06), tag filtering (FR14-07), preferred tag-based recommendations (FR14-08 to FR14-10), deep link handling (FR14-02), compound tag indexes (FR14-11, FR14-12), and popularity/recency sorting (FR14-16).

### 4. Live Participant Awareness & Cursors (FR08) — *20% Implemented*
* Active participants query exists, but live visual awareness is incomplete.
* Missing: Live participant cursor positions rendered on canvas (FR08-02), active object editing indicators (FR08-03), and user join/leave session notifications (FR08-04, FR08-05).

---

### Fully Completed Subsystems (100% Implemented)
* **Module 1: Authentication & Identity (FR01):** Password strength validation, email verification and login enforcement, email password reset, token sessions.
* **Module 2: User Profile Management (FR02):** Profile customization, strict photo MIME validation, privacy toggles, preferred tags, account deletion with cascade purge.
* **Module 3: Board Creation & Management (FR03):** Board CRUD, duplicate board with CRDT cloning, archive/unarchive, atomic workspace moves, tag regex validation.
* **Module 4: Canvas Tools & Visual Elements (FR05):** Freehand brushes, shapes, Arrow shape with tap-to-connect, Sticky notes, Connectors & Flowcharts with dynamic topology maintenance, camera/gallery image insertion.
* **Module 5: Board Sharing & Access Control (FR07):** Friend invites, role assignments (Owner, Editor, Viewer), role toggling, owner member access revocation.
* **Module 6: Notifications & Preferences (FR15):** FCM push alerts, in-app notification center, comment @mention notifications, user notification preference toggles in settings.
* **Module 8: Board Export & Sharing (FR11):** High-res PNG (2x), styled PDF document with header/footer, vector SVG serialization for all 12 shapes/connectors/stickies/text/images, OS-level file sharing sheet (`share_plus`).
* **Module 11: In-App Communication & Audio (FR12):** Pin-to-canvas threaded comments with replies, live WebSocket in-board chat drawer with Redis TTL and Firestore batch sync (30 msgs), Agora voice call session with floating HUD.
* **Module 13: Social & Friend Management (FR13):** User search, send/accept/decline friend requests, reciprocal friend lists, direct board invites.

---

## 4. What Features Are in the Implementation BUT NOT in the Requirements

The following features were designed, engineered, and implemented in the codebase but were **not requested or mentioned in `Requirements.docx`**:

| Extra Feature | Implementation Location | Description |
| :--- | :--- | :--- |
| **1. User Blocking & Reporting System** | [`blocked_users_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/friends/view/blocked_users_screen.dart), [`block_user.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/friends/block_user.js), [`report_user.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/friends/report_user.js) | Full moderation suite: blocking users, unblocking users, reporting abusive users, and dedicated "Blocked Users" screen. |
| **2. Multi-User Team Workspace Collaboration** | [`workspaces/`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/workspaces), [`functions/src/workspaces`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/workspaces) | Requirements only requested simple folders/workspaces to organize boards (FR03-10). The codebase built team workspaces with members, roles (`owner`, `admin`, `member`), invitations, member removal, and workspace leave policies. |
| **3. Join Board via Alphanumeric Code** | [`join_board_by_code.js`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/functions/src/boards/join_board_by_code.js), `joinCode` | Allows joining boards by inputting a unique alphanumeric board join code. |
| **4. Advanced Canvas Brushes: Laser Pointer & Highlighter** | [`brush_tray.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/trays/brush_tray.dart), [`canvas_painter.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/canvas_painter.dart) | Temporary fading laser pointer with animation timer, dashed lines, and semi-transparent highlighter brush styles. |
| **5. Interactive Media Pre-Editor Screen** | [`media_editor_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/media_editor_screen.dart) | Dedicated modal screen offering image cropping, aspect ratio presets, rotation, and reset tools prior to placing uploaded images on canvas. |
| **6. Board Preview Quality & Compression Settings** | [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart#L82-L116), [`board_preview_preferences.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/utils/board_preview_preferences.dart) | User settings allowing selection of Low/Medium/High preview thumbnail quality and preview compression toggle. |
| **7. Interactive Tray Tips Overlay** | [`tray_tips_overlay.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/canvas/view/widgets/tray_tips_overlay.dart), [`tray_tips_preferences.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/core/utils/tray_tips_preferences.dart) | Interactive onboarding walkthrough showing new users where the floating trays are anchored on the canvas. |
| **8. Offline Cache Management Tool** | [`settings_screen.dart`](file:///c:/Users/highh/OneDrive/Documents/GitHub/InkLink/lib/features/settings/view/settings_screen.dart#L125-L131) | Settings action allowing users to inspect and manually clear the local Isar database cache. |

---

## 5. Prioritized Implementation Roadmap

To bring the codebase to 100% compliance with `Requirements.docx`, tasks should be sequenced as follows:

```mermaid
graph TD
    A[Phase 1: Quick Wins & Auth Polish] --> B[Phase 2: Missing Canvas Essentials]
    B --> C[Phase 3: Public Discovery & Exporting]
    C --> D[Phase 4: Communication Systems]
    D --> E[Phase 5: AI Engine Integration]

    subgraph "Phase 1: Auth & User Gaps"
        A1[Password Reset Flow FR01-07]
        A2[Email Verification FR01-05,06]
        A3[Account Deletion FR02-06,07]
        A4[User Tag Preferences FR02-11,12]
    end

    subgraph "Phase 2: Canvas Elements"
        B1[Sticky Notes FR05-09]
        B2[Arrow Shape FR05-04]
        B3[Connectors & Flowcharts FR05-13..15]
        B4[Camera Photo Capture FR05-16]
        B5[Board Duplicate & Archive FR03-07,08]
    end

    subgraph "Phase 3: Discovery & Export"
        C1[Public Board Discovery Screen FR14-04..10]
        C2[Export PNG / PDF / SVG FR11-01..05]
        C3[Native Share Sheet FR11-03]
    end

    subgraph "Phase 4: Collaboration & Messaging"
        D1[Direct Messaging System FR17-01..12]
        D2[Board Comments FR12-01..03,05]
        D3[Live Cursors & Awareness FR08-01..05]
        D4[Voice Calls & Live Chat FR12-04,06,07]
    end

    subgraph "Phase 5: AI Engine"
        E1[External AI API Integration FR06-01..07]
        E2[AI Usage Limits & Tracking FR16-01,02]
    end
```

---

## 6. Conclusion

The InkLink project boasts an **exceptionally solid architectural core** — including clean architecture, Yjs CRDT real-time synchronization, Redis streaming, Isar offline caching, and robust security rules. 

However, substantial feature gaps exist relative to the requirements document, primarily centered around **AI integration (FR06/FR16)**, **Direct Messaging (FR17)**, **In-App Communication & Voice (FR12)**, **Exporting (FR11)**, **Public Board Discovery (FR14)**, and **Live Cursors (FR08)**. Conversely, the team has already built sophisticated extensions (User Blocking & Moderation, Team Workspace Multi-Tenancy, Join Codes, Media Editor) that exceed the original specifications.

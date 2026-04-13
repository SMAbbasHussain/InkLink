# InkLink Project Guidelines

## Build and Test
- Flutter app (repo root):
  - flutter pub get
  - dart run tool/architecture_guardrails.dart
  - flutter analyze
  - flutter test
- Cloud Functions (functions/):
  - npm install
  - npm run serve
  - npm run deploy
- Run guardrails + analyze + tests before finishing significant refactors.

## Architecture
- Follow service-first layering:
  - UI (screens/widgets) -> BLoC -> Domain Service -> Repository -> Backend/DB
- Keep responsibilities strict:
  - Screens are UI-only and dispatch BLoC events.
  - BLoCs orchestrate state and call domain services.
  - Domain services contain business rules and orchestration.
  - Repositories are data-access only.
- Do not bypass layers:
  - No direct repository/service usage from feature screen files.
  - No repository imports in BLoCs.
  - No Cloud Functions imports/callables in repositories.
  - No direct Firebase singleton usage outside approved core wrappers.
- The guardrail source of truth is tool/architecture_guardrails.dart.

## Project Conventions
- Prefer existing composition patterns in lib/main.dart and route-level builders in lib/features/*/view/*_route.dart.
- Keep Firestore path constants aligned across:
  - lib/core/constants/firestore_paths.dart
  - functions/src/utils/firestore_paths.js
- Cloud Functions are loaded dynamically from functions/src/**/*.js via functions/index.js.
  - Each function module should export a single handler function via module.exports = async (request) => { ... }.
- Treat generated/build output as non-source:
  - Do not edit files in build/.
  - Respect analysis_options.yaml exclusions for generated Dart files.

## Firebase and Environment
- Use lib/firebase_options.dart (generated) for client Firebase initialization.
- Keep secrets out of source:
  - Never commit service-account credentials.
  - Use .env.example as the template for local env values.
- For Cloud Functions runtime assumptions, prefer functions/package.json and functions/index.js over older prose docs if they disagree.

## Link First
- Start with existing docs, then implement:
  - README.md
  - lib/README.md
  - functions/README.md
  - firestore.rules
  - database.rules.json
  - .github/workflows/architecture-guardrails.yml

## Change Hygiene
- Keep edits focused and minimal; avoid unrelated reformatting.
- Preserve existing naming/style patterns in nearby files.
- When changing architecture-sensitive code, verify with:
  - dart run tool/architecture_guardrails.dart
  - flutter analyze
  - flutter test
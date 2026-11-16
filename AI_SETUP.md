# AI image generation: setup and testing

## 1. What it does

On a board, the **Media tray** can generate an image from a prompt in three shapes (1:1, 16:9, 9:16). A selected AI image can be changed with **Edit with AI**, **Repaint area** (paint a mask, describe what goes there) and **Regenerate**. Every result is a normal image element, so collaborators see it live and undo/redo works.

```
Flutter app                      Cloud Function                  Cloudflare
───────────                      ──────────────                  ──────────
Media tray / action bar
   │  AiImageBloc → AiImageService
   │  httpsCallable(generateAiImage | editAiImage | inpaintAiImage)
   ├──────────────────────────────►  auth → validate → edit access
   │                                 → daily limit (ai_usage)
   │                                 → provider ───────────────► Workers AI
   │                                 ◄──────────── image ───────  (FLUX.2 klein)
   │                                 → PNG → R2 upload ────────► R2 bucket
   │                                 → thumbnail → ai_generations
   ◄──── {imageUrl, thumbnailBase64, width, height, ...}
   │
   └─ CanvasBloc → CRDT update (imageUrl + small thumbnail) → collaborators
```

Key points:

- **The app never sees the provider or its key.** It only calls three Cloud Functions and receives an image URL.
- **Images are stored by URL**, not inline. The element also carries a 256px thumbnail, so older app versions still show a (low-res) picture.
- **The mock provider needs no key.** It is used automatically when no token is set, and returns coloured test images after about 1.5 seconds.
- **Limits:** 20 AI requests per user per day (UTC) by default. Only owners and editors can use AI.

## 2. Create the Cloudflare token

1. Sign in at <https://dash.cloudflare.com>. Use the **same account** that owns the R2 bucket, because the functions reuse the existing `CLOUDFLARE_ACCOUNT_ID` secret.
2. **Account ID:** open the account home (or **Workers & Pages**). The Account ID is shown in the right-hand sidebar. You only need it if `CLOUDFLARE_ACCOUNT_ID` is not already set as a Functions secret.
3. **Token:** go to **My Profile → API Tokens → Create Token**. Use the **Workers AI** template, or a custom token with the account permissions **Workers AI - Read** and **Workers AI - Edit**. Limit it to this one account.
4. Copy the token once. Do not put it in `.env`, `.env.example`, the app, or git.
5. FLUX models are covered by Black Forest Labs' terms (<https://bfl.ai/legal/terms-of-service>). Read them before shipping.

## 3. Deploy

```bash
# 1. Store the token as a Functions secret (paste it when asked)
firebase functions:secrets:set CLOUDFLARE_AI_API_TOKEN

# 2. Install dependencies (adds sharp)
cd functions && npm install && cd ..

# 3. Deploy only the three new functions
firebase deploy --only functions:generateAiImage,functions:editAiImage,functions:inpaintAiImage
```

The functions also need the R2 secrets that profile photo upload already uses (`CLOUDFLARE_R2_ACCESS_KEY`, `CLOUDFLARE_R2_SECRET_KEY`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_R2_BUCKET`, `CLOUDFLARE_R2_PUBLIC_URL`). If avatars upload today, these are already set.

In the app, add this line to your local `.env` (it is not a secret) and rebuild:

```
AI_IMAGE_ENABLED=true
```

Without it the tray keeps the old "Generate Image (Soon)" button.

## 4. Test without a key (mock provider)

### 4a. Automated tests, no setup at all

```bash
cd functions
npm test          # 32 tests: validation, access, daily limit, mock provider, mask compositing
cd ..
flutter test      # includes the AI service, bloc, canvas element and widget tests
```

These use the mock provider and fakes. No network, no Firebase, no key.

### 4b. The whole flow in the app, with the mock provider

The secret must exist for the deploy to succeed, so give it a placeholder value and force the mock provider:

```bash
# Placeholder value, for example: mock
firebase functions:secrets:set CLOUDFLARE_AI_API_TOKEN

# functions/.env is git-ignored. This forces the mock provider.
echo AI_PROVIDER=mock > functions/.env

cd functions && npm install && cd ..
firebase deploy --only functions:generateAiImage,functions:editAiImage,functions:inpaintAiImage
```

Now run the app with `AI_IMAGE_ENABLED=true` and work through the checklist below. Generated "images" are solid colours; edits tint the image; repaint tints only the painted area.

When you are ready for the real API: set the real token (step 3), delete the `AI_PROVIDER=mock` line from `functions/.env`, and deploy again.

### 4c. Functions emulator (not verified)

```bash
cd functions
# R2 values for the emulator; *.local files are git-ignored
printf 'CLOUDFLARE_ACCOUNT_ID=...\nCLOUDFLARE_R2_ACCESS_KEY=...\nCLOUDFLARE_R2_SECRET_KEY=...\nCLOUDFLARE_R2_BUCKET=...\nCLOUDFLARE_R2_PUBLIC_URL=...\n' > .secret.local
npm run shell
# then, in the shell:
generateAiImage({data: {boardId: '<a board you own>', prompt: 'a red fox', aspectRatio: '16:9'}}, {auth: {uid: '<your uid>'}})
```

Two limits to know:

- This still uploads to the real R2 bucket and reads the real Firestore, so it needs your Firebase login and the R2 values.
- **The app cannot talk to the emulator today.** `CloudFunctionsServiceImpl` always uses the deployed `us-central1` functions, and changing that file was outside this task. Use 4b to test from the app.

I have not run this route; treat the commands as a starting point.

## 5. Manual test checklist

Run once with the mock provider and once with the real token.

- [ ] **Generate, 1:1.** A loading box appears in the middle of the view, then becomes an image.
- [ ] **Generate, 16:9 and 9:16.** The image has the chosen shape.
- [ ] **Keep drawing** while an image is generating.
- [ ] **Edit with AI.** The image changes; position and size stay.
- [ ] **Repaint area.** Paint a region, type a prompt. Only that region changes.
- [ ] **Regenerate.** A new variation replaces the image.
- [ ] **Undo / redo** after each of: generate, edit, repaint, regenerate. One undo goes back one version.
- [ ] **Move and resize** an AI image, then reopen the board. It is still sharp (not just the thumbnail).
- [ ] **Second user** on the same board sees the image appear and change live.
- [ ] **Viewer.** The tray controls and the action bar are disabled with an explanation. Calling the function directly is refused.
- [ ] **Daily limit.** Set `AI_DAILY_LIMIT=2` in `functions/.env`, deploy, make 3 requests. The third shows the limit message and no image appears.
- [ ] **No key → mock.** With `AI_PROVIDER` unset and no real token, images are solid colours.
- [ ] **Offline.** Turn off the network and tap Generate. A clear error shows, the loading box disappears, the board is unchanged.
- [ ] **Flag off.** Remove `AI_IMAGE_ENABLED` from `.env`, rebuild. The tray shows "Generate Image (Soon)" and the old message.
- [ ] **Old board.** Open a board made before this change, with uploaded images. It looks the same and exports the same (PNG, PDF, SVG).
- [ ] **Export** a board with an AI image. The export shows the full-quality image.
- [ ] **Older app build** opens a board with an AI image and shows the low-res thumbnail (no crash, no grey box).

## 6. TODO: confirm the FLUX.2 klein request format

`@cf/black-forest-labs/flux-2-klein-4b` takes multipart form data, but Cloudflare's docs do not list the field names. The code assumes `prompt`, `width`, `height` and `input_image_0`, and that input images must fit in 512px.

- **Where:** `functions/src/ai/ai_provider_utils.js`, function `callKlein`, marked `// UNVERIFIED: confirm field names with first real call`. It is the only place that builds the klein request.
- **How to check:** make one real Generate and one real Edit, then read the function logs (`firebase functions:log`). A wrong field name shows as "AI image request rejected" with code `invalid-argument` or `unavailable`.
- **Until it is confirmed:** Generate still works if klein fails, because it falls back to `flux-1-schnell` (always square). Edit and Repaint have no fallback.
- `strength` is accepted by `editAiImage` but not sent to klein, since no such field is documented.
- **Repaint** is not true inpainting. No current Cloudflare model offers it, so the whole image is edited and the result is kept only inside the mask (edge feathered by 4px).

## 7. Limits, configuration and switching provider

**Cloudflare free tier:** 10,000 neurons per day, reset at 00:00 UTC. `flux-1-schnell` costs about 58 neurons for a 1024×1024 image (4 steps). Check the current FLUX.2 klein price at <https://developers.cloudflare.com/workers-ai/platform/pricing/>; edits also pay for the input image. Past the free amount, requests fail unless the account is on Workers Paid.

**Settings** (plain values in `functions/.env`, not secrets; redeploy after changing):

| Name | Default | Meaning |
|---|---|---|
| `AI_DAILY_LIMIT` | `20` | AI requests per user per UTC day. Only successful requests count. |
| `AI_PROVIDER` | `cloudflare` if the token is set, else `mock` | Force `mock` or `cloudflare`. |

Usage is stored in Firestore at `ai_usage/{uid}_{YYYYMMDD}`. Each result is logged at `ai_generations/{generationId}`. Both are written only by the functions; the app does not read them, so no security rule is needed for clients (the default deny is correct).

**Switching provider (Gemini, OpenAI, ...):** only `functions/src/ai/ai_provider_utils.js` changes. Add a `createXxxProvider` with the same three methods (`generate`, `edit`, `inpaint`, each returning `{buffer, width, height, model}`) and return it from `getProvider`. Add its secret to `aiSecrets` in `functions/index.js`. The app needs no change.

**Storage:** images are saved at `ai-images/{boardId}/{generationId}.png` in the existing R2 bucket and served from `CLOUDFLARE_R2_PUBLIC_URL`. Anyone who has the URL can open the image, the same as profile photos. Old versions are not deleted when an image is edited (undo needs them), and deleting a board does not delete its AI images yet.

## 8. Future work

- Crop/adjust and rotation for AI images (not in v1).
- Prompt history UI (the data is already in `ai_generations`).
- Clean up R2 objects when a board or image is deleted.
- Flutter web: image loading already uses bytes, not files, but the web build itself is untested.
- Point the app at the Functions emulator for local testing.

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Whether AI image generation is switched on.
///
/// Reads the non-secret `AI_IMAGE_ENABLED` value from `.env`. Anything other
/// than `true` (missing value, `.env` not loaded, typo) means OFF, in which
/// case the canvas keeps its previous "coming soon" behaviour. Never throws.
bool isAiImageEnabled([Map<String, String>? env]) {
  try {
    final source = env ?? dotenv.env;
    final raw = source['AI_IMAGE_ENABLED'];
    return raw != null && raw.trim().toLowerCase() == 'true';
  } catch (_) {
    // dotenv throws when .env was never loaded.
    return false;
  }
}

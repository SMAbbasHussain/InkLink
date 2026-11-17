/**
 * Cloud Function: editAiImage
 *
 * Edits a whole AI image from a text instruction ("make it night time").
 *
 * Input:  {boardId, sourceImageUrl, prompt, strength?}   strength: 0..1, default 0.7
 * Output: {success, imageUrl, thumbnailBase64, width, height, provider, model, generationId}
 *
 * sourceImageUrl must be one of this board's AI images in our R2 bucket.
 * Requires auth and edit access to the board. Counts against the caller's
 * daily AI limit. See ai_request_utils.js for the shared pipeline.
 */

const { runAiRequest } = require('./ai_request_utils');

module.exports = async (request) => runAiRequest(request, 'edit');

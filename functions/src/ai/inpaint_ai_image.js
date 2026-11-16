/**
 * Cloud Function: inpaintAiImage
 *
 * Repaints only the masked part of an AI image (white in the mask = repaint).
 *
 * Input:  {boardId, sourceImageUrl, maskBase64, prompt}   mask: PNG, at most 4 MB
 * Output: {success, imageUrl, thumbnailBase64, width, height, provider, model, generationId}
 *
 * sourceImageUrl must be one of this board's AI images in our R2 bucket.
 * Requires auth and edit access to the board. Counts against the caller's
 * daily AI limit. See ai_request_utils.js for the shared pipeline.
 */

const { runAiRequest } = require('./ai_request_utils');

module.exports = async (request) => runAiRequest(request, 'inpaint');

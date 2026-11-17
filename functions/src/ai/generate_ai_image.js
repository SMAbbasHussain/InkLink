/**
 * Cloud Function: generateAiImage
 *
 * Generates an image from a text prompt and stores it in R2.
 *
 * Input:  {boardId, prompt, aspectRatio}   aspectRatio: 1:1 | 16:9 | 9:16
 * Output: {success, imageUrl, thumbnailBase64, width, height, provider, model, generationId}
 *
 * Requires auth and edit access to the board. Counts against the caller's
 * daily AI limit. See ai_request_utils.js for the shared pipeline.
 */

const { runAiRequest } = require('./ai_request_utils');

module.exports = async (request) => runAiRequest(request, 'generate');

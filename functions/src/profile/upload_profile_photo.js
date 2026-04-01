/**
 * Cloud Function: Upload Profile Photo
 * 
 * Uploads a user's profile photo to Cloudflare R2 object storage
 * and returns the public URL for storing in Firestore.
 * 
 * @param {object} request - The callable request object
 * @param {object} request.auth - Authentication context {uid, token, ...}
 * @param {object} request.data - Request data {imageData, filename}
 * @returns {object} {success: true, photoUrl: string}
 * @throws {HttpsError} Various validation and execution errors
 */

const { HttpsError } = require("firebase-functions/v2/https");
const admin = require("../../server/firebase-admin");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { validateUID, validateString } = require("../utils/validation");
const logger = require("../utils/logger");

module.exports = async (request) => {
  const { data, auth } = request;
  const uid = auth?.uid;

  try {
    // Fail fast if required Cloudflare configuration is missing.
    const requiredEnvVars = [
      'CLOUDFLARE_ACCOUNT_ID',
      'CLOUDFLARE_R2_ACCESS_KEY',
      'CLOUDFLARE_R2_SECRET_KEY',
      'CLOUDFLARE_R2_BUCKET',
      'CLOUDFLARE_R2_PUBLIC_URL',
    ];
    const missingEnvVars = requiredEnvVars.filter(
      (key) => !process.env[key] || process.env[key].trim().length === 0
    );
    if (missingEnvVars.length > 0) {
      logger.error('Upload profile photo: Missing Cloudflare configuration', {
        missingEnvVars,
      });
      throw new HttpsError(
        'failed-precondition',
        'Server storage configuration is incomplete. Contact support.'
      );
    }

    // Validate authentication
    if (!auth) {
      logger.warn('Upload profile photo: Missing authentication');
      throw new HttpsError('unauthenticated', 'User must be logged in.');
    }

    if (!uid) {
      logger.warn('Upload profile photo: Invalid auth object');
      throw new HttpsError('unauthenticated', 'Invalid authentication.');
    }

    // Validate input data
    if (!data) {
      logger.warn('Upload profile photo: Missing request data', { uid });
      throw new HttpsError('invalid-argument', 'Request data is required.');
    }

    const { imageData, filename } = data;

    // Validate image data (base64 encoded)
    if (!imageData || typeof imageData !== 'string') {
      logger.warn('Upload profile photo: Invalid imageData', { uid });
      throw new HttpsError('invalid-argument', 'imageData must be a non-empty base64 string.');
    }

    // Validate filename
    try {
      validateString(filename, 'filename');
    } catch (validationError) {
      logger.warn('Upload profile photo: Invalid filename', {
        filename,
        uid,
        error: validationError.message
      });
      throw new HttpsError('invalid-argument', 'filename must be a non-empty string.');
    }

    // Validate UID format
    try {
      validateUID(uid);
    } catch (validationError) {
      logger.warn('Upload profile photo: Invalid UID', {
        uid,
        error: validationError.message
      });
      throw new HttpsError('invalid-argument', 'Invalid user ID format.');
    }

    // Verify user exists in Firestore
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) {
      logger.warn('Upload profile photo: User not found', { uid });
      throw new HttpsError('not-found', 'User account not found.');
    }

    // Validate base64 string and convert to buffer
    let imageBuffer;
    try {
      // Check if it's valid base64 (simple validation)
      if (!imageData.match(/^[A-Za-z0-9+/=]+$/)) {
        throw new Error('Invalid base64 format');
      }
      imageBuffer = Buffer.from(imageData, 'base64');
    } catch (error) {
      logger.warn('Upload profile photo: Invalid base64 image', {
        uid,
        error: error.message
      });
      throw new HttpsError('invalid-argument', 'imageData must be valid base64 encoded data.');
    }

    // Check image size (max 5MB)
    const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5MB
    if (imageBuffer.length > MAX_IMAGE_SIZE) {
      logger.warn('Upload profile photo: Image too large', {
        uid,
        size: imageBuffer.length,
        maxSize: MAX_IMAGE_SIZE
      });
      throw new HttpsError('invalid-argument', 'Image is too large. Maximum size is 5MB.');
    }

    // Initialize S3 client for Cloudflare R2
    const s3Client = new S3Client({
      region: 'auto',
      credentials: {
        accessKeyId: process.env.CLOUDFLARE_R2_ACCESS_KEY,
        secretAccessKey: process.env.CLOUDFLARE_R2_SECRET_KEY,
      },
      endpoint: `https://${process.env.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    });

    // Generate unique filename with timestamp
    const timestamp = Date.now();
    const sanitizedFilename = filename
      .replace(/[^a-zA-Z0-9._-]/g, '_') // Remove special characters
      .substring(0, 100); // Limit filename length
    const objectKey = `profiles/${uid}/${timestamp}-${sanitizedFilename}`;

    // Upload to Cloudflare R2
    try {
      const uploadCommand = new PutObjectCommand({
        Bucket: process.env.CLOUDFLARE_R2_BUCKET,
        Key: objectKey,
        Body: imageBuffer,
        ContentType: getContentType(filename),
      });

      const uploadResponse = await s3Client.send(uploadCommand);
      logger.info('Profile photo uploaded to R2', {
        uid,
        objectKey,
        etag: uploadResponse.ETag,
      });
    } catch (s3Error) {
      logger.error('Upload profile photo: R2 upload failed', s3Error);
      throw new HttpsError('internal', 'Failed to upload image. Please try again later.');
    }

    // Construct public URL for the uploaded image
    // Format: https://{account}.r2.cloudflarestorage.com/{bucket}/{key}
    // Or if using a custom domain: https://yourdomain.com/{key}

    if (!process.env.CLOUDFLARE_R2_PUBLIC_URL || process.env.CLOUDFLARE_R2_PUBLIC_URL.trim().length === 0) {
      logger.error('Upload profile photo: Missing CLOUDFLARE_R2_PUBLIC_URL env var');
      throw new HttpsError(
        'failed-precondition',
        'Server storage configuration is incomplete. Contact support.'
      );
    }
    const publicBase = process.env.CLOUDFLARE_R2_PUBLIC_URL.replace(/\/$/, ''); // strip trailing slash
    const photoUrl = `${publicBase}/${objectKey}`;

    logger.info('Upload profile photo: Success', {
      uid,
      photoUrl,
      photoKey: objectKey,
    });

    return {
      success: true,
      photoUrl,
    };
  } catch (error) {
    // Re-throw HttpsErrors as-is
    if (error instanceof HttpsError) {
      throw error;
    }

    // Log unexpected errors
    logger.error('Upload profile photo: Unexpected error', error);
    throw new HttpsError(
      'internal',
      'An unexpected error occurred during upload. Please try again later.'
    );
  }
};

/**
 * Determine MIME type based on filename extension
 * @param {string} filename - The filename
 * @returns {string} MIME type
 */
function getContentType(filename) {
  const extension = filename.toLowerCase().split('.').pop();
  const mimeTypes = {
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    gif: 'image/gif',
    webp: 'image/webp',
  };
  return mimeTypes[extension] || 'application/octet-stream';
}

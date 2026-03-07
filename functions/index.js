const path = require('path');
const admin = require('./server/firebase-admin');
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const glob = require("glob");
const logger = require('./src/utils/logger');

// FIX: Load Firebase region from environment or use default
const FIREBASE_REGION = process.env.FIREBASE_REGION || 'us-central1';

// Define any secrets needed by your functions
const mySecrets = [];

/**
 * Dynamically load and export all Cloud Functions from src/ directory
 * Supports nested folders: src/auth/login.js -> exports.auth_login
 * 
 * Function naming rules:
 * - src/accept_friend_request.js -> exports.accept_friend_request
 * - src/auth/login.js -> exports.auth_login
 */
const apiFiles = glob.sync(`src/**/*.js`, {
    cwd: __dirname,
    // Ignore utility files
    ignore: ['src/utils/**/*.js']
});

apiFiles.forEach(filePath => {
    try {
        const functionName = filePath
            .replace(/^src[\\/]/, '')   // remove src/ or src\
            .replace(/\.js$/, '')
            .replace(/[\\/]/g, '_')
            .replace(/_([a-z])/g, (_, c) => c.toUpperCase());

        const absolutePath = path.resolve(__dirname, filePath);

        // FIX: Validate that the handler exists and is a function
        let handler;
        try {
            handler = require(absolutePath);
        } catch (loadError) {
            logger.error(`Failed to load function from ${filePath}`, loadError);
            return;
        }

        if (typeof handler !== 'function') {
            logger.warn(`Handler in ${filePath} is not a function, skipping`);
            return;
        }

        // Create the Cloud Function with proper error handling
        exports[functionName] = onCall(
            {
                secrets: mySecrets,
                region: FIREBASE_REGION,
                // FIX: Removed unnecessary CORS flag (not used for callable functions)
                // CORS is only needed for HTTP functions, not callable functions
                timeoutSeconds: 540, // 9 minutes - Firebase default
            },
            async (request) => {
                try {
                    logger.debug(`Executing function: ${functionName}`, {
                        uid: request.auth?.uid,
                        dataKeys: Object.keys(request.data || {})
                    });

                    // Call the handler with the request object
                    const result = await handler(request);

                    logger.info(`Function succeeded: ${functionName}`, {
                        uid: request.auth?.uid,
                        hasResult: !!result
                    });

                    return result;
                } catch (error) {
                    // FIX: Better error handling and logging
                    if (error instanceof HttpsError) {
                        // If handler threw HttpsError, re-throw it as-is
                        logger.warn(`Function failed with HttpsError: ${functionName}`, {
                            code: error.code,
                            message: error.message,
                            uid: request.auth?.uid
                        });
                        throw error;
                    } else {
                        // Unexpected errors get logged with full context
                        logger.error(`Function failed with unexpected error: ${functionName}`, error);
                        throw new HttpsError(
                            'internal',
                            'An unexpected error occurred. Please try again later.'
                        );
                    }
                }
            }
        );

        logger.info(`Loaded Cloud Function: ${functionName} from ${filePath}`);
    } catch (error) {
        logger.error(`Error loading function file: ${filePath}`, error);
    }
});

logger.info(`Cloud Functions initialized in region: ${FIREBASE_REGION}`);
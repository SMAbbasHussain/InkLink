/**
 * Logging utility for Cloud Functions
 * Provides structured logging for debugging and monitoring
 */

const functions = require('firebase-functions');

/**
 * Log an info level message
 * @param {string} message - The message to log
 * @param {object} data - Optional additional data
 */
function info(message, data = {}) {
  functions.logger.info(message, data);
}

/**
 * Log a warning level message
 * @param {string} message - The message to log
 * @param {object} data - Optional additional data
 */
function warn(message, data = {}) {
  functions.logger.warn(message, data);
}

/**
 * Log an error level message
 * @param {string} message - The message to log
 * @param {Error|object} error - The error or error data
 */
function error(message, error) {
  if (error instanceof Error) {
    functions.logger.error(message, { 
      errorMessage: error.message, 
      stack: error.stack 
    });
  } else {
    functions.logger.error(message, error);
  }
}

/**
 * Log a debug level message (only in development)
 * @param {string} message - The message to log
 * @param {object} data - Optional additional data
 */
function debug(message, data = {}) {
  if (process.env.DEBUG === 'true') {
    functions.logger.debug(message, data);
  }
}

module.exports = {
  info,
  warn,
  error,
  debug,
};

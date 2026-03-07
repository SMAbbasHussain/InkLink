/**
 * Input validation utilities for Cloud Functions
 * Provides centralized validation logic to prevent invalid data from reaching handlers
 */

/**
 * Validates that a value is a non-empty string
 * @param {*} value - The value to validate
 * @param {string} fieldName - Name of the field (for error messages)
 * @returns {boolean} True if valid, throws error otherwise
 */
function validateString(value, fieldName) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`${fieldName} must be a non-empty string`);
  }
  return true;
}

/**
 * Validates that a value is a valid Firebase UID
 * Firebase UIDs are typically 28 characters of alphanumeric + special chars
 * @param {*} uid - The UID to validate
 * @param {string} fieldName - Name of the field (for error messages)
 * @returns {boolean} True if valid, throws error otherwise
 */
function validateUID(uid, fieldName = 'UID') {
  validateString(uid, fieldName);
  if (uid.length < 20 || uid.length > 128) {
    throw new Error(`${fieldName} has invalid format`);
  }
  return true;
}

/**
 * Validates that two UIDs are different
 * @param {string} uid1 - First UID
 * @param {string} uid2 - Second UID
 * @returns {boolean} True if different, throws error otherwise
 */
function validateDifferentUIDs(uid1, uid2) {
  if (uid1 === uid2) {
    throw new Error('Cannot perform operation: UIDs must be different');
  }
  return true;
}

/**
 * Validates that a request ID exists and is non-empty
 * @param {*} requestId - The request ID to validate
 * @returns {boolean} True if valid, throws error otherwise
 */
function validateRequestId(requestId) {
  validateString(requestId, 'requestId');
  // requestId format: "uid1_uid2" (deterministic, lowercase)
  const parts = requestId.split('_');
  if (parts.length !== 2 || parts.some(p => p.length < 20)) {
    throw new Error('requestId has invalid format');
  }
  return true;
}

module.exports = {
  validateString,
  validateUID,
  validateDifferentUIDs,
  validateRequestId,
};

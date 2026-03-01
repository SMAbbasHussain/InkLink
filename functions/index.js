const path = require('path');
const admin = require('./server/firebase-admin');
const { onCall } = require("firebase-functions/v2/https");
const glob = require("glob");

// Define your secrets
const mySecrets = [];

// Scan for files directly in functions/src/
const apiFiles = glob.sync(`src/*.js`, { cwd: __dirname });

apiFiles.forEach(filePath => {
    // Filename becomes the function name (e.g., src/accept_request.js -> accept_request)
    const functionName = path.basename(filePath, '.js');
    const absolutePath = path.resolve(__dirname, filePath);
    const handler = require(absolutePath);

    exports[functionName] = onCall(
        { 
            secrets: mySecrets, 
            region: 'us-central1', // Adjust to your Firebase region
            preserveExternalChanges: true,
            cors: true 
        },
        async (request) => {
            // Your handler must be an async function receiving the v2 request object
            return handler(request);
        }
    );
});
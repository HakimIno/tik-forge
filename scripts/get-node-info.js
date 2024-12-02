const fs = require('fs');
const os = require('os');
const path = require('path');

// Get Node.js version without 'v' prefix
const version = process.version.slice(1);
const username = os.userInfo().username;
const homedir = os.homedir();

// Write to temporary file
fs.writeFileSync('node-info.txt', JSON.stringify({
    version,
    username,
    homedir
}));

console.log('Node.js info:', {
    version,
    username,
    homedir
}); 
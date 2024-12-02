const fs = require('fs');
const os = require('os');

const info = {
    version: process.version.slice(1),
    username: os.userInfo().username,
    homedir: os.homedir()
};

console.log('Node.js info:', info);
fs.writeFileSync('node-info.txt', JSON.stringify(info)); 
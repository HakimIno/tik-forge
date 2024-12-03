const path = require('path');
const fs = require('fs');

function loadAddon() {
    try {
        // ลองโหลดจาก prebuilt ก่อน
        const prebuiltPath = path.resolve(__dirname, 'prebuilds', process.platform + '-' + process.arch, 'tik-forge.node');
        if (fs.existsSync(prebuiltPath)) {
            console.log('Loading prebuilt addon from:', prebuiltPath);
            return require(prebuiltPath);
        }

        // ถ้าไม่มี prebuilt ลองโหลดจาก build
        const buildPath = path.resolve(__dirname, 'build/Release/tik-forge.node');
        if (fs.existsSync(buildPath)) {
            console.log('Loading built addon from:', buildPath);
            return require(buildPath);
        }

        // ถ้าไม่มีทั้ง prebuilt และ build ให้ build ใหม่
        console.log('No addon found, building from source...');
        require('./scripts/build.js');
        return require(buildPath);

    } catch (err) {
        console.error('Failed to load tik-forge native addon:', err);
        throw err;
    }
}

module.exports = loadAddon();
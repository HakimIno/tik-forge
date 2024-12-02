const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function checkZig() {
    try {
        execSync('zig version', { stdio: 'ignore' });
        return true;
    } catch (e) {
        return false;
    }
}

function main() {
    // ตรวจสอบว่ามี Zig หรือไม่
    if (!checkZig()) {
        console.error('Zig is required but not found.');
        console.error('Please install Zig from https://ziglang.org/');
        process.exit(1);
    }

    // Build
    try {
        execSync('zig build', { stdio: 'inherit' });
    } catch (e) {
        console.error('Failed to build:', e);
        process.exit(1);
    }

    console.log('Build completed successfully');
}

main(); 
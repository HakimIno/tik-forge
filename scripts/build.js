const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

async function main() {
    try {
        // Set environment variables
        const env = {
            ...process.env,
            NODE_VERSION: process.version.slice(1),  // Remove 'v' prefix
            HOME: require('os').homedir()
        };

        // Build Zig library
        console.log('Building Zig library...');
        execSync('zig build', { 
            stdio: 'inherit',
            env: env
        });

        // Create build/Release directory if it doesn't exist
        const releaseDir = path.join(__dirname, '..', 'build', 'Release');
        fs.mkdirSync(releaseDir, { recursive: true });

        // Build node addon
        console.log('Building node addon...');
        execSync('node-gyp rebuild', { 
            stdio: 'inherit',
            env: env
        });

        console.log('Build completed successfully');
    } catch (e) {
        console.error('Build failed:', e.message);
        process.exit(1);
    }
}

main();
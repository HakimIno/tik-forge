const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

function installNodeHeaders() {
    const nodeVersion = process.version.slice(1);
    console.log('Installing Node.js headers for version:', nodeVersion);
    
    try {
        // Get Node.js executable path and installation directory
        const nodePath = process.execPath;
        const nodeDir = path.dirname(nodePath);
        const nodeRoot = path.dirname(nodeDir);

        execSync('node-gyp install', {
            stdio: 'inherit',
            env: {
                ...process.env,
                npm_config_nodedir: nodeRoot,
                NODE: nodePath,
                NODE_VERSION: nodeVersion,
                NODE_ROOT: nodeRoot
            }
        });

        console.log('Node.js headers installed successfully');
    } catch (e) {
        console.error('Failed to install Node.js headers:', e.message);
        process.exit(1);
    }
}

function main() {
    // Install Node.js headers first
    installNodeHeaders();

    try {
        // Try to use prebuild-install first
        const prebuildInstall = path.join(__dirname, '../node_modules/.bin/prebuild-install');
        if (fs.existsSync(prebuildInstall)) {
            try {
                execSync(`"${prebuildInstall}"`, { stdio: 'inherit' });
                console.log('Successfully installed prebuilt binary');
                return;
            } catch (e) {
                console.log('No prebuilt binary found, building from source...');
            }
        }

        // Build from source using zig
        const nodePath = process.execPath;
        execSync('zig build', {
            stdio: 'inherit',
            env: {
                ...process.env,
                NODE: nodePath
            }
        });
        console.log('Successfully built from source');
    } catch (e) {
        console.error('Build failed:', e.message);
        process.exit(1);
    }
}

main(); 
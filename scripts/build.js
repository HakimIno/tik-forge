const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Map Node.js target to Zig target
const targetMap = {
    'darwin-x64': 'x86_64-macos',
    'darwin-arm64': 'aarch64-macos',
    'linux-x64': 'x86_64-linux',
    'linux-arm64': 'aarch64-linux'
};

// Map platform to file extension
const extensionMap = {
    'darwin': '.node.dylib',
    'linux': '.node.so'
};

// Get current platform and architecture
const currentPlatform = process.platform;
const currentArch = process.env.ARCH || process.arch;
const target = `${currentPlatform}-${currentArch}`;

console.log(`Building for ${target}...`);

try {
    // Convert target to Zig format
    const zigTarget = targetMap[target];
    if (!zigTarget) {
        throw new Error(`Unknown target: ${target}`);
    }
    
    // Get correct file extension
    const platform = target.split('-')[0];
    const extension = extensionMap[platform];
    
    // Build for target
    execSync(`zig build -Dtarget=${zigTarget}`, { stdio: 'inherit' });
    
    // Check if library was built
    const libPath = path.join(__dirname, '..', 'zig-out', 'zig-out', 'lib');
    const libFile = path.join(libPath, `libtik-forge${extension}`);
    
    if (!fs.existsSync(libFile)) {
        throw new Error(`Library not found at ${libFile}`);
    }
    
    // Copy to the location node-gyp expects
    const destPath = path.join(__dirname, '..', 'build', 'Release');
    if (!fs.existsSync(destPath)) {
        fs.mkdirSync(destPath, { recursive: true });
    }
    fs.copyFileSync(libFile, path.join(destPath, 'tik-forge.node'));
    
    console.log(`Built successfully for ${target}`);
} catch (error) {
    console.error(`Build failed for ${target}: ${error.message}`);
    process.exit(1);
}